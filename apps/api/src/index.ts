import express from "express";
import cors from "cors";

const app = express();
const port = Number(process.env.PORT || 4000);

app.use(cors());
app.use(express.json());

// Endpoints de comprobación de salud exigidos por PRD sección 10
app.get("/health/live", (req, res) => {
  res.status(200).json({ status: "alive", timestamp: Date.now() });
});

app.get("/health/ready", (req, res) => {
  res.status(200).json({ status: "ready", uptime: process.uptime() });
});

// Metadatos de mundos / islas públicas
app.get("/api/worlds", (req, res) => {
  res.json({
    worlds: [
      {
        id: "isla-esperanza-01",
        name: "Isla Esperanza",
        maxPlayers: 16,
        currentPlayers: 1,
        region: "sa-east-1",
        version: "1.0.0",
      },
    ],
  });
});

app.listen(port, () => {
  console.log(`[API] Wildborn REST API escuchando en el puerto ${port}`);
});
