# Security Implementation

## Overview
This browser-in-container system implements multiple security layers to protect against unauthorized access and ensure iframe embedding is restricted to authorized domains.

## Authentication

### API Token Authentication
All API endpoints require authentication via Bearer token:

```bash
Authorization: Bearer <AUTH_TOKEN>
```

### Environment Configuration
Set the following environment variable:
```bash
AUTH_TOKEN=your-secure-token-here
```

### Protected Endpoints
- `POST /session` - Create new browser session
- `POST /heartbeat/:sessionId` - Keep session alive
- `GET /session/:sessionId/downloads` - List downloads
- `GET /download/:sessionId/:filename` - Download file
- `POST /stop/:sessionId` - Stop session
- `GET /admin/users` - List all users
- `POST /browser-command/:sessionId` - Browser navigation
- `GET /vnc/:sessionId/*` - VNC proxy access

## iframe Security

### Domain Restriction
iframe embedding is restricted to `portal2.ai` domain only via:

1. **X-Frame-Options Header**: `ALLOW-FROM https://portal2.ai`
2. **Content-Security-Policy**: `frame-ancestors 'self' https://portal2.ai https://www.portal2.ai`
3. **CORS Policy**: Only allows requests from portal2.ai domains

### VNC Access Control
- VNC access is proxied through authenticated endpoints
- Session validation before allowing VNC connections
- Referer header validation for additional security
- Direct port access should be blocked via firewall

## CORS Configuration
Restricted to authorized domains:
```javascript
origin: ['https://portal2.ai', 'https://www.portal2.ai', 'http://localhost:8090', 'http://localhost:8095']
```

## Security Headers
The following security headers are automatically applied:
- `X-Frame-Options: ALLOW-FROM https://portal2.ai`
- `Content-Security-Policy: frame-ancestors 'self' https://portal2.ai https://www.portal2.ai`

## Testing Security

Run the security test script:
```bash
./test-security.sh
```

Expected results:
- Unauthorized requests return HTTP 401
- Authorized requests return HTTP 200
- iframe embedding only works on portal2.ai

## Production Deployment

### Environment Variables
```bash
AUTH_TOKEN=your-very-secure-random-token
ALLOWED_DOMAIN=portal2.ai
NODE_ENV=production
```

### Additional Security Recommendations
1. **Firewall Rules**: Block direct access to VNC ports (5901-5999)
2. **SSL/TLS**: Use HTTPS in production
3. **Token Rotation**: Regularly rotate AUTH_TOKEN
4. **Rate Limiting**: Implement rate limiting for production
5. **Monitoring**: Log all authentication attempts
6. **Network Security**: Use VPC/private networks when possible

## Error Responses

### 401 Unauthorized
```json
{
  "error": "Unauthorized - Invalid or missing token"
}
```

### 403 Forbidden
```json
{
  "error": "Access denied - unauthorized domain"
}
```

### 404 Not Found
```json
{
  "error": "Session not found"
}
```