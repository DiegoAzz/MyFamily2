#!/bin/sh
set -e

echo "=========================================================="
echo "🌲 INICIANDO WILDBORN ONLINE EN PRODUCCIÓN (COOLIFY)"
echo "=========================================================="

# Arrancar el servidor de juego Colyseus en segundo plano
echo "🚀 Arrancando Game Server en el puerto 2567..."
node /app/apps/game-server/dist/index.js &
SERVER_PID=$!

# Arrancar Nginx en primer plano
echo "🌐 Arrancando Servidor Web Nginx en el puerto 80..."
nginx -g "daemon off;" &
NGINX_PID=$!

# Manejar señales de terminación para apagado graceful
trap "kill -TERM $SERVER_PID $NGINX_PID" SIGTERM SIGINT
wait
