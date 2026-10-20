#!/bin/sh
node /app/server/relay.js &
nginx -g "daemon off;"
