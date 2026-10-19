FROM nginx:alpine

# Copiar configuracion de nginx con cabeceras COOP/COEP
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiar build web exportada de Godot
COPY build/web /usr/share/nginx/html

# Exponer puertos 3000 (default en Coolify) y 80
EXPOSE 3000
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
