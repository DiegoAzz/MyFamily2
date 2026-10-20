FROM nginx:alpine

# Instalar nodejs y npm para el servidor WebSocket relay
RUN apk add --no-cache nodejs npm

WORKDIR /app
COPY server /app/server
RUN cd /app/server && npm install ws

# Copiar configuracion de nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiar build web exportada de Godot
COPY build/web /usr/share/nginx/html

# Script de arranque para ejecutar el relay y nginx juntos
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000
EXPOSE 80

CMD ["/entrypoint.sh"]
