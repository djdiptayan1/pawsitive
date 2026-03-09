import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import app from './src/app.js';
import { setupTrackingWS } from './src/ws/trackingServer.js';
import { ENV } from './src/config/env.js';

const server = createServer(app);

// Attach WebSocket server to same HTTP server (same port!)
const wss = new WebSocketServer({ server, path: '/ws/track' });
setupTrackingWS(wss);

server.listen(ENV.PORT, () => {
    console.log(`
🐾 Pawsitive Backend Running
─────────────────────────────
🌐 HTTP:  http://localhost:${ENV.PORT}/api
🔌 WS:    ws://localhost:${ENV.PORT}/ws/track
❤️  Health: http://localhost:${ENV.PORT}/api/health
─────────────────────────────`);
});

// Graceful shutdown
process.on('unhandledRejection', (err) => {
    console.error('Unhandled rejection:', err);
    process.exit(1);
});

// Graceful shutdown helper
const shutdown = (signal) => {
    console.log(`Received ${signal}. Closing server...`);

    // Terminate all websocket connections
    wss.clients.forEach((client) => {
        client.terminate();
    });

    server.close(() => {
        console.log('Server closed.');
        if (signal === 'SIGUSR2') {
            process.kill(process.pid, 'SIGUSR2');
        } else {
            process.exit(0);
        }
    });

    // Force close if it takes too long
    setTimeout(() => {
        console.error('Could not close connections in time, forcefully shutting down');
        if (signal === 'SIGUSR2') {
            process.kill(process.pid, 'SIGUSR2');
        } else {
            process.exit(1);
        }
    }, 3000);
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.once('SIGUSR2', () => shutdown('SIGUSR2'));
