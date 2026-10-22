# ========================================================
# WILDBORN ONLINE — UNIFIED PRODUCTION DOCKERFILE
# ========================================================

# Stage 1: Build all workspaces
FROM node:20-alpine AS builder
WORKDIR /app

# Instalar dependencias
COPY package*.json ./
COPY tsconfig.base.json ./
COPY packages/ ./packages/
COPY apps/ ./apps/

RUN npm install
RUN npm run build --workspace=@wildborn/shared
RUN npm run build --workspace=@wildborn/game-content
RUN npm run build --workspace=@wildborn/game-server
RUN npm run build --workspace=@wildborn/web

# Stage 2: Runtime con Nginx y Node.js juntos
FROM nginx:alpine AS runner
WORKDIR /app

# Instalar Node.js para ejecutar el servidor Colyseus
RUN apk add --no-cache nodejs npm

# Copiar paquetes y servidor compilado
COPY package*.json ./
COPY packages/ ./packages/
COPY --from=builder /app/apps/game-server/dist ./apps/game-server/dist
COPY --from=builder /app/apps/game-server/package.json ./apps/game-server/package.json
COPY --from=builder /app/packages/shared/dist ./packages/shared/dist
COPY --from=builder /app/packages/game-content/dist ./packages/game-content/dist

# Instalar dependencias de producción para el servidor
RUN npm install --omit=dev

# Copiar cliente web compilado a Nginx
COPY --from=builder /app/apps/web/dist /usr/share/nginx/html

# Configuración Nginx y script de arranque
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
EXPOSE 2567

CMD ["/entrypoint.sh"]
