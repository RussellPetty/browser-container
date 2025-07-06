FROM node:18-alpine

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY server.js ./

# Create user profiles directory
RUN mkdir -p user-profiles && \
    chown -R node:node user-profiles

# Switch to non-root user
USER node

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/admin/users -H "Authorization: Bearer ${AUTH_TOKEN}" || exit 1

# Start the application
CMD ["node", "server.js"]