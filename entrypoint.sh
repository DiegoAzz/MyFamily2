#!/bin/sh
echo '[Entrypoint] Iniciando Relay Node.js...'
cd /app/server && node relay.js &
echo '[Entrypoint] Iniciando Nginx en puertos 3000 y 80...'
nginx -g 'daemon off;'
