const { WebSocketServer } = require('ws');

const port = process.env.PORT || 8080;
const wss = new WebSocketServer({ port: port });

console.log(`[MyFamily Relay] WebSocket Server running on port ${port}`);

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
    console.log(`[MyFamily Relay] Client connected from ${ip}. Total connections: ${wss.clients.size}`);

    ws.on('message', (rawMessage) => {
        let msg;
        try {
            msg = JSON.parse(rawMessage.toString());
        } catch (e) {
            console.error(`[MyFamily Relay] JSON parse error:`, e.message);
            return;
        }

        const type = msg.type;

        // 1. CREAR SALA (HOST)
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

            console.log(`[MyFamily Relay] Room active: [${code}] by client ${ws.clientId}. Total in room: ${roomSet.size}`);

            ws.send(JSON.stringify({
                type: 'room_created',
                code: code,
                clientId: ws.clientId,
                totalPlayers: roomSet.size
            }));
            return;
        }

        // 2. UNIRSE A SALA (GUEST)
        if (type === 'join_room') {
            const code = (msg.code || '').trim().toUpperCase();
            if (!code || !rooms.has(code)) {
                ws.send(JSON.stringify({
                    type: 'error',
                    message: `La sala "${code}" no existe. Pídele el código a tu amigo.`
                }));
                return;
            }

            const roomSet = rooms.get(code);
            ws.roomCode = code;
            ws.clientId = msg.clientId || String(Math.floor(Math.random() * 90000 + 10000));
            ws.isHost = false;
            roomSet.add(ws);

            console.log(`[MyFamily Relay] Client ${ws.clientId} joined room [${code}]. Total in room: ${roomSet.size}`);

            ws.send(JSON.stringify({
                type: 'room_joined',
                code: code,
                clientId: ws.clientId,
                totalPlayers: roomSet.size
            }));

            // Notificar a los demás en la sala
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

        // 4. OTROS EVENTOS
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
            console.log(`[MyFamily Relay] Client ${ws.clientId} left room [${ws.roomCode}]. Remaining: ${roomSet.size}`);

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
                console.log(`[MyFamily Relay] Room [${ws.roomCode}] deleted (empty).`);
            }
        }
    });

    ws.on('error', (err) => {
        console.error(`[MyFamily Relay] Client error:`, err.message);
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
        console.error('[MyFamily Relay] Heartbeat error:', e.message);
    }
}, 25000);

wss.on('close', () => {
    clearInterval(interval);
});
