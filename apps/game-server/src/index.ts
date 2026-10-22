import http from "http";
import express from "express";
import cors from "cors";
import colyseus from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { IslandRoom } from "./rooms/IslandRoom.js";

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

app.get("/", (req, res) => {
  res.send("🌲 Servidor autoritativo de Wildborn Online activo y escuchando conexiones WSS.");
});

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
