import http from "http";
import express from "express";
import cors from "cors";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import colyseus from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { IslandRoom } from "./rooms/IslandRoom.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const port = Number(process.env.PORT || 2567);
const app = express();

app.use(cors());
app.use(express.json());

// Healthcheck para Docker y Coolify
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    service: "wildborn-game-server",
    uptime: process.uptime(),
    timestamp: Date.now(),
  });
});

// Servir archivos estáticos del cliente 3D (React + Babylon.js)
const candidatePaths = [
  path.resolve(__dirname, "../../web/dist"),
  path.resolve(__dirname, "../web/dist"),
  path.resolve("/app/apps/web/dist"),
  path.resolve("/usr/share/nginx/html"),
];

const webDistPath = candidatePaths.find((p) => fs.existsSync(p));

if (webDistPath) {
  console.log(`[GameServer] Sirviendo cliente web 3D desde: ${webDistPath}`);
  app.use(express.static(webDistPath));

  // SPA fallback para React Router / URLs directas
  app.get("*", (req, res, next) => {
    if (
      req.path.startsWith("/matchmake") ||
      req.path.startsWith("/health") ||
      req.path.startsWith("/colyseus") ||
      req.path.startsWith("/island")
    ) {
      return next();
    }
    const indexPath = path.join(webDistPath, "index.html");
    if (fs.existsSync(indexPath)) {
      res.sendFile(indexPath);
    } else {
      next();
    }
  });
} else {
  console.warn("[GameServer] No se encontró el directorio de distribución web.");
  app.get("/", (req, res) => {
    res.send("🌲 Servidor autoritativo de Wildborn Online activo y escuchando conexiones WSS.");
  });
}

const server = http.createServer(app);

const gameServer = new colyseus.Server({
  transport: new WebSocketTransport({
    server,
    pingInterval: 5000,
    pingMaxRetries: 3,
  }),
});

// Registrar sala autoritativa de la isla
gameServer.define("island", IslandRoom);

server.listen(port, () => {
  console.log(`====================================================`);
  console.log(`🌲 WILDBORN ONLINE — GAME SERVER ACTIVO`);
  console.log(`🚀 Escuchando en el puerto: ${port}`);
  console.log(`🌐 Sala de isla registrada: 'island'`);
  console.log(`====================================================`);
});
