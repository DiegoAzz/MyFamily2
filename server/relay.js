const http = require('http');
const { WebSocketServer } = require('ws');

const RELAY_PORT = 8080;

// Servidor HTTP base para responder a comprobaciones y alojar WebSockets
const server = http.createServer((req, res) => {
    res.writeHead(200, { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify({ 
        status: 'ok', 
        service: 'MyFamily Relay Server',
        activeRooms: rooms.size,
        totalClients: wss.clients.size 
    }));
});

const wss = new WebSocketServer({ server });

server.listen(RELAY_PORT, '0.0.0.0', () => {
    console.log(`[MyFamily Relay] Servidor HTTP y WebSocket activo en 0.0.0.0:${RELAY_PORT}`);
});

process.on('uncaughtException', (err) => {
    console.error('[MyFamily Relay] Error no capturado:', err.message);
});
process.on('unhandledRejection', (reason) => {
    console.error('[MyFamily Relay] Rechazo no manejado:', reason);
});

// Mapa de salas activas: roomCode -> Set<ws>
const rooms = new Map();

// Diccionario de palabras amigables para códigos fáciles de compartir
const WORDS = [
    "VALE", "CASA", "LUNA", "SOLO", "RANA", "PATO", "GATO", "FLOR",
    "ARBO", "BOSQ", "ISLA", "MAYO", "AZUL", "ROJO", "VIDA", "AMOR",
    "PAZ", "ARTE", "RIOS", "LAGO", "CIEL", "FARO", "NUBE", "ESTA"
];

function generateRoomCode() {
    for (const w of WORDS) {
        if (!rooms.has(w)) return w;
    }
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

wss.on('connection', (ws, req) => {
    ws.isAlive = true;
    ws.roomCode = null;
    ws.clientId = null;
    ws.isHost = false;

    ws.on('pong', () => {
        ws.isAlive = true;
    });

    const ip = req.socket.remoteAddress;
    console.log(`[MyFamily Relay] Cliente conectado desde ${ip}. Conexiones totales: ${wss.clients.size}`);

    ws.on('message', (rawMessage) => {
        let msg;
        try {
            msg = JSON.parse(rawMessage.toString());
        } catch (e) {
            console.error(`[MyFamily Relay] JSON parse error:`, e.message);
            return;
        }

        const type = msg.type;

        // 1. CREAR / REGISTRAR SALA (HOST)
        if (type === 'create_room') {
            const proposedCode = (msg.code || '').trim().toUpperCase();
            const code = proposedCode || generateRoomCode();
            ws.roomCode = code;
            ws.clientId = msg.clientId || String(Math.floor(Math.random() * 90000 + 10000));
            ws.isHost = true;

            let roomSet = rooms.get(code);
            if (!roomSet) {
                roomSet = new Set();
                rooms.set(code, roomSet);
            }
            roomSet.add(ws);

            console.log(`[MyFamily Relay] Sala activa: [${code}] (Host: ${ws.clientId}). Jugadores en sala: ${roomSet.size}`);

            ws.send(JSON.stringify({
                type: 'room_created',
                code: code,
                clientId: ws.clientId,
                totalPlayers: roomSet.size
            }));
            return;
        }

        // 2. UNIRSE A SALA (GUEST / AMIGO)
        if (type === 'join_room') {
            const code = (msg.code || '').trim().toUpperCase();
            if (!code) {
                ws.send(JSON.stringify({
                    type: 'error',
                    message: `Por favor introduce un código de sala válido.`
                }));
                return;
            }

            let roomSet = rooms.get(code);
            if (!roomSet) {
                roomSet = new Set();
                rooms.set(code, roomSet);
                console.log(`[MyFamily Relay] Sala [${code}] inicializada al unirse.`);
            }

            ws.roomCode = code;
            ws.clientId = msg.clientId || String(Math.floor(Math.random() * 90000 + 10000));
            ws.isHost = false;
            roomSet.add(ws);

            console.log(`[MyFamily Relay] Cliente ${ws.clientId} se unió a sala [${code}]. Total en sala: ${roomSet.size}`);

            // Responder al cliente que se unió
            ws.send(JSON.stringify({
                type: 'room_joined',
                code: code,
                clientId: ws.clientId,
                totalPlayers: roomSet.size
            }));

            // Notificar a todos los demás en la sala
            roomSet.forEach((client) => {
                if (client !== ws && client.readyState === 1) {
                    client.send(JSON.stringify({
                        type: 'player_joined',
                        clientId: ws.clientId,
                        totalPlayers: roomSet.size
                    }));
                }
            });
            return;
        }

        // 3. SINCRONIZACIÓN DE ESTADO (movimiento, posición, animación)
        if (type === 'state') {
            if (ws.roomCode && rooms.has(ws.roomCode)) {
                const roomSet = rooms.get(ws.roomCode);
                roomSet.forEach((client) => {
                    if (client !== ws && client.readyState === 1) {
                        client.send(rawMessage);
                    }
                });
            }
            return;
        }

        // 4. OTROS MENSAJES
        if (ws.roomCode && rooms.has(ws.roomCode)) {
            const roomSet = rooms.get(ws.roomCode);
            roomSet.forEach((client) => {
                if (client !== ws && client.readyState === 1) {
                    client.send(rawMessage);
                }
            });
        }
    });

    ws.on('close', () => {
        if (ws.roomCode && rooms.has(ws.roomCode)) {
            const roomSet = rooms.get(ws.roomCode);
            roomSet.delete(ws);
            console.log(`[MyFamily Relay] Cliente ${ws.clientId} salió de sala [${ws.roomCode}]. Quedan: ${roomSet.size}`);

            roomSet.forEach((client) => {
                if (client.readyState === 1) {
                    client.send(JSON.stringify({
                        type: 'player_left',
                        clientId: ws.clientId,
                        totalPlayers: roomSet.size
                    }));
                }
            });

            if (roomSet.size === 0) {
                rooms.delete(ws.roomCode);
                console.log(`[MyFamily Relay] Sala [${ws.roomCode}] eliminada por estar vacía.`);
            }
        }
    });

    ws.on('error', (err) => {
        console.error(`[MyFamily Relay] Error en socket:`, err.message);
    });
});

// Heartbeat seguro cada 25 segundos
const interval = setInterval(() => {
    try {
        wss.clients.forEach((ws) => {
            if (ws.isAlive === false) return ws.terminate();
            ws.isAlive = false;
            ws.ping();
        });
    } catch (e) {
        console.error('[MyFamily Relay] Error en heartbeat:', e.message);
    }
}, 25000);

wss.on('close', () => {
    clearInterval(interval);
});
