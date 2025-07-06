const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { exec } = require('child_process');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs').promises;
const cors = require('cors');
const fetch = require('node-fetch');
const app = express();

// Security headers for iframe restriction
app.use((req, res, next) => {
  res.setHeader('X-Frame-Options', 'ALLOW-FROM https://portal2.ai');
  res.setHeader('Content-Security-Policy', "frame-ancestors 'self' https://portal2.ai https://www.portal2.ai");
  next();
});

// Restrict CORS to portal2.ai only
app.use(cors({
  origin: ['https://portal2.ai', 'https://www.portal2.ai', 'http://localhost:8090', 'http://localhost:8095'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

app.use(express.json());
app.use(express.static('public'));

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!process.env.AUTH_TOKEN) {
    console.warn('AUTH_TOKEN not set in environment variables');
    return res.status(500).json({ error: 'Server configuration error' });
  }
  
  if (!token || token !== process.env.AUTH_TOKEN) {
    return res.status(401).json({ error: 'Unauthorized - Invalid or missing token' });
  }
  
  next();
};

// Store active sessions and user profiles
const sessions = new Map();
const userProfiles = new Map(); // Map userId to profile data

// Create profile directory if it doesn't exist
const PROFILES_DIR = './user-profiles';

async function ensureProfilesDir() {
  try {
    await fs.access(PROFILES_DIR);
  } catch {
    await fs.mkdir(PROFILES_DIR, { recursive: true });
  }
}

// Generate consistent user ID from identifier (email, username, etc.)
function getUserId(userIdentifier) {
  return crypto.createHash('sha256').update(userIdentifier).digest('hex').substring(0, 16);
}

// Create new browser session
app.post('/session', authenticateToken, async (req, res) => {
  const sessionId = uuidv4();
  const startUrl = req.body.url || 'https://google.com';
  const userIdentifier = req.body.userId || req.body.email || `anonymous-${sessionId}`;
  
  try {
    await ensureProfilesDir();
    
    // Generate consistent user ID
    const userId = getUserId(userIdentifier);
    const userProfilePath = path.join(PROFILES_DIR, userId);
    
    // Ensure user profile directory exists
    try {
      await fs.access(userProfilePath);
    } catch {
      await fs.mkdir(userProfilePath, { recursive: true });
      console.log(`Created new user profile for: ${userIdentifier} (${userId})`);
    }
    
    // For local testing with Docker - simplified command without volume mounts
    const command = `docker run -d -p 0:5901 \\
      -e START_URL="${startUrl}" \\
      -e SESSION_ID="${sessionId}" \\
      -e SESSION_API_URL="http://172.17.0.1:3000" \\
      --network browser-container_browser-network \\
      --name chrome-${sessionId} \\
      remote-chrome-final-fixed`;
    
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.error('Error starting container:', error);
        return res.status(500).json({ error: 'Failed to start session' });
      }
      
      // Get the mapped port
      exec(`docker port chrome-${sessionId} 5901`, (portError, portStdout) => {
        if (portError) {
          return res.status(500).json({ error: 'Failed to get port' });
        }
        
        const port = portStdout.trim().split('\n')[0].split('0.0.0.0:')[1];
        const iframeSrc = `http://localhost:3000/vnc/${sessionId}/vnc.html?autoconnect=true&resize=scale`;
        
        sessions.set(sessionId, {
          containerId: `chrome-${sessionId}`,
          userId,
          userIdentifier,
          port,
          lastActivity: Date.now(),
          status: 'active',
          downloads: []
        });
        
        // Track user profile usage
        userProfiles.set(userId, {
          userIdentifier,
          lastUsed: Date.now(),
          sessionsCount: (userProfiles.get(userId)?.sessionsCount || 0) + 1
        });
        
        res.json({ 
          sessionId, 
          iframeSrc, 
          userId,
          isReturningUser: userProfiles.get(userId)?.sessionsCount > 1
        });
      });
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Heartbeat endpoint
app.post('/heartbeat/:sessionId', authenticateToken, (req, res) => {
  const { sessionId } = req.params;
  const session = sessions.get(sessionId);
  
  if (session) {
    session.lastActivity = Date.now();
    
    // Update user profile last used time
    const userProfile = userProfiles.get(session.userId);
    if (userProfile) {
      userProfile.lastUsed = Date.now();
    }
    
    if (session.status === 'paused') {
      // Resume container
      exec(`docker unpause ${session.containerId}`);
      session.status = 'active';
    }
    res.json({ status: 'ok' });
  } else {
    res.status(404).json({ error: 'Session not found' });
  }
});

// Download notification endpoint
app.post('/download-notification', authenticateToken, (req, res) => {
  const { sessionId, filename, filepath, filesize, timestamp } = req.body;
  const session = sessions.get(sessionId);
  
  if (session) {
    // Store download info
    if (!session.downloads) session.downloads = [];
    
    const download = {
      filename,
      filepath,
      filesize,
      timestamp,
      downloadUrl: `http://localhost:3000/download/${sessionId}/${encodeURIComponent(filename)}`,
      downloaded: false
    };
    
    session.downloads.push(download);
    console.log(`Download ready: ${filename} (${filesize} bytes) for session ${sessionId}`);
    
    res.json({ status: 'notified', download });
  } else {
    res.status(404).json({ error: 'Session not found' });
  }
});

// List downloads for a session
app.get('/session/:sessionId/downloads', authenticateToken, (req, res) => {
  const { sessionId } = req.params;
  const session = sessions.get(sessionId);
  
  if (session && session.downloads) {
    res.json({ downloads: session.downloads });
  } else {
    res.json({ downloads: [] });
  }
});

// Proxy download files
app.get('/download/:sessionId/:filename', authenticateToken, async (req, res) => {
  const { sessionId, filename } = req.params;
  const session = sessions.get(sessionId);
  
  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }
  
  try {
    // For Docker: access file directly from mounted volume
    const filePath = path.join(PROFILES_DIR, session.userId, 'Downloads', filename);
    
    // Check if file exists
    await fs.access(filePath);
    
    // Mark as downloaded
    const download = session.downloads?.find(d => d.filename === filename);
    if (download) download.downloaded = true;
    
    // Stream file to user
    res.download(filePath, filename);
    
  } catch (error) {
    console.error('Download error:', error);
    res.status(404).json({ error: 'File not found' });
  }
});

// Get user profile info
app.get('/user/:userId', authenticateToken, (req, res) => {
  const { userId } = req.params;
  const profile = userProfiles.get(userId);
  
  if (profile) {
    res.json({
      userId,
      userIdentifier: profile.userIdentifier,
      lastUsed: profile.lastUsed,
      sessionsCount: profile.sessionsCount,
      hasProfile: true
    });
  } else {
    res.json({ userId, hasProfile: false });
  }
});

// List all user sessions for admin
app.get('/admin/users', authenticateToken, (req, res) => {
  const users = Array.from(userProfiles.entries()).map(([userId, profile]) => ({
    userId,
    userIdentifier: profile.userIdentifier,
    lastUsed: profile.lastUsed,
    sessionsCount: profile.sessionsCount
  }));
  
  res.json({ users, totalUsers: users.length });
});

// Stop session endpoint
app.post('/stop/:sessionId', authenticateToken, (req, res) => {
  const { sessionId } = req.params;
  const session = sessions.get(sessionId);
  
  if (session) {
    exec(`docker stop ${session.containerId} && docker rm ${session.containerId}`, (error) => {
      if (error) {
        console.error('Error stopping container:', error);
        return res.status(500).json({ error: 'Failed to stop session' });
      }
      
      sessions.delete(sessionId);
      res.json({ status: 'stopped' });
    });
  } else {
    res.status(404).json({ error: 'Session not found' });
  }
});

// Session lifecycle management (30-minute pause, 3-day destroy containers but KEEP PROFILES)
setInterval(() => {
  const now = Date.now();
  const idleTimeout = 30 * 60 * 1000; // 30 minutes - pause when idle
  const graceTimeout = 3 * 24 * 60 * 60 * 1000; // 3 days - destroy container but KEEP profile
  
  sessions.forEach((session, sessionId) => {
    const inactiveTime = now - session.lastActivity;
    
    if (inactiveTime > graceTimeout) {
      // Delete container after 3 days but PRESERVE user profile data
      exec(`docker rm -f ${session.containerId}`);
      sessions.delete(sessionId);
      console.log(`Deleted session ${sessionId} after 3 days - USER PROFILE PRESERVED`);
    } else if (inactiveTime > idleTimeout && session.status === 'active') {
      // Pause container after 30 minutes of inactivity
      exec(`docker pause ${session.containerId}`);
      session.status = 'paused';
      console.log(`Paused session ${sessionId} after 30 minutes idle`);
    }
  });
}, 60000); // Check every minute

// Browser command endpoint for navigation controls
app.post('/browser-command/:sessionId', authenticateToken, (req, res) => {
  const { sessionId } = req.params;
  const { action, url } = req.body;
  const session = sessions.get(sessionId);
  
  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }
  
  // Send commands to the browser container
  let command;
  switch (action) {
    case 'back':
      command = `docker exec ${session.containerId} xdotool key --window \$(xdotool search --class chromium) alt+Left`;
      break;
    case 'forward':
      command = `docker exec ${session.containerId} xdotool key --window \$(xdotool search --class chromium) alt+Right`;
      break;
    case 'refresh':
      command = `docker exec ${session.containerId} xdotool key --window \$(xdotool search --class chromium) F5`;
      break;
    case 'navigate':
      command = `docker exec ${session.containerId} xdotool key --window \$(xdotool search --class chromium) ctrl+l && echo "${url}" | docker exec -i ${session.containerId} xdotool type --stdin && docker exec ${session.containerId} xdotool key Return`;
      break;
    default:
      return res.status(400).json({ error: 'Unknown action' });
  }
  
  exec(command, (error) => {
    if (error) {
      console.error('Browser command error:', error);
      return res.status(500).json({ error: 'Failed to execute command' });
    }
    res.json({ status: 'success' });
  });
});

// VNC proxy endpoint with session validation (no auth required for browser access)
app.get('/vnc/:sessionId/*', (req, res) => {
  const { sessionId } = req.params;
  const session = sessions.get(sessionId);
  
  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }
  
  // Check if session is active
  if (session.status !== 'active') {
    return res.status(403).json({ error: 'Session not active' });
  }
  
  // Validate referring domain for iframe security
  const referer = req.headers.referer;
  if (referer && !referer.includes('portal2.ai') && !referer.includes('localhost')) {
    return res.status(403).json({ error: 'Access denied - unauthorized domain' });
  }
  
  // Get the VNC path after the session ID - extract from the original URL
  const fullPath = req.path; // e.g., "/vnc/sessionId/vnc.html"
  const vncPath = fullPath.replace(`/vnc/${sessionId}/`, ''); // e.g., "vnc.html"
  const queryString = req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : '';
  
  // Get the host from the request and replace port 3000 with the VNC port
  const host = req.get('host') || 'localhost:3000';
  const protocol = req.secure ? 'https' : 'http';
  const vncHost = host.replace(':3000', `:${session.port}`);
  const vncUrl = `${protocol}://${vncHost}/${vncPath}${queryString}`;
  
  // Simple redirect to the VNC URL
  res.redirect(vncUrl);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Session manager running on port ${PORT}`);
  console.log('API endpoints:');
  console.log('  POST /session - Create new browser session');
  console.log('  POST /heartbeat/:sessionId - Keep session alive');
  console.log('  GET /session/:sessionId/downloads - List downloads');
  console.log('  GET /download/:sessionId/:filename - Download file');
  console.log('  POST /stop/:sessionId - Stop session');
  console.log('  GET /admin/users - List all users');
});