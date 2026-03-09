// Two room types:
// 1. rescuerClients  → Map<rescuerId, WebSocket>
//    All online rescuers connect here on app open.
//    Used to broadcast new SOS alerts.
//
// 2. incidentRooms   → Map<incidentId, Set<WebSocket>>
//    Citizen + assigned rescuer join after accept.
//    Used for live GPS relay + status updates.

const rescuerClients = new Map();  // rescuerId (string) → WebSocket
const incidentRooms = new Map();  // incidentId (string) → Set<WebSocket>

export function setupTrackingWS(wss) {
    wss.on('connection', (ws, req) => {
        const url = new URL(req.url, 'ws://x');
        const role = url.searchParams.get('role');       // 'rescuer' | 'citizen'
        const userId = url.searchParams.get('userId');
        const incidentId = url.searchParams.get('incident');   // present after accept

        if (!userId) { ws.close(4001, 'userId required'); return; }

        // --- Rescuer registers as available ---
        if (role === 'rescuer') {
            rescuerClients.set(userId, ws);
            console.log(`✅ Rescuer online: ${userId} (total: ${rescuerClients.size})`);

            ws.on('close', () => {
                rescuerClients.delete(userId);
                console.log(`⬇️  Rescuer offline: ${userId}`);
            });
        }

        // --- Join incident room (both citizen + rescuer after accept) ---
        if (incidentId) {
            if (!incidentRooms.has(incidentId)) {
                incidentRooms.set(incidentId, new Set());
            }
            incidentRooms.get(incidentId).add(ws);
            console.log(`🚨 ${role} joined incident room: ${incidentId}`);

            ws.on('close', () => {
                incidentRooms.get(incidentId)?.delete(ws);
                if (incidentRooms.get(incidentId)?.size === 0) {
                    incidentRooms.delete(incidentId); // cleanup empty room
                }
            });
        }

        ws.on('error', (err) => console.error('WS error:', err.message));
    });
}

// Broadcast SOS to specific rescuer IDs (called from POST /incidents)
export function broadcastToRescuers(rescuerIds, payload) {
    const message = JSON.stringify(payload);
    let sent = 0;
    rescuerIds.forEach(id => {
        const ws = rescuerClients.get(id);
        if (ws?.readyState === 1) {   // 1 = OPEN
            ws.send(message);
            sent++;
        }
    });
    console.log(`📡 SOS broadcast: ${sent}/${rescuerIds.length} rescuers reached`);
}

// Relay message to everyone in an incident room (called from routes)
export function broadcastToIncidentRoom(incidentId, payload) {
    const room = incidentRooms.get(incidentId);
    if (!room) return;
    const message = JSON.stringify(payload);
    room.forEach(ws => {
        if (ws.readyState === 1) ws.send(message);
    });
}