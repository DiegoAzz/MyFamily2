const { WebSocketServer } = require('ws');

const port = process.env.PORT || 8080;
const wss = new WebSocketServer({ port: port });

console.log(`[MyFamily Relay] WebSocket Server running on port ${port}`);

wss.on('connection', (ws, req) => {
    const ip = req.socket.remoteAddress;
    console.log(`[MyFamily Relay] Client connected from ${ip}. Total: ${wss.clients.size}`);

    ws.on('message', (message, isBinary) => {
        // Retransmitir el mensaje a todos los demás clientes conectados
        wss.clients.forEach((client) => {
            if (client !== ws && client.readyState === 1) { // 1 = OPEN
                client.send(message, { binary: isBinary });
            }
        });
    });

    ws.on('close', () => {
        console.log(`[MyFamily Relay] Client disconnected. Total: ${wss.clients.size}`);
    });

    ws.on('error', (err) => {
        console.error(`[MyFamily Relay] Client error:`, err.message);
    });
});
