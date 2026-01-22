# Stage 1: Base - install dependencies
FROM node:18-slim AS base

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/
COPY webpack.config.js ./

# Stage 2: Development - for local development with hot reload
FROM base AS development

ENV NODE_ENV=development

EXPOSE 3001

CMD ["npm", "start"]

# Stage 3: Builder - build production assets
FROM base AS builder

ENV NODE_ENV=production

# Build the app
RUN npm run build

# Stage 4: Production - nginx serving static files
FROM nginx:alpine AS production

# Copy built assets from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration (will be mounted in production)
# Default nginx config works for basic serving

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
