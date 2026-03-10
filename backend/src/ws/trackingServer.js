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
            // Normalise UUID to lowercase to prevent case-mismatch with Supabase UUIDs
            const normalisedId = userId.toLowerCase();
            rescuerClients.set(normalisedId, ws);
            console.log(`✅ Rescuer online: ${normalisedId} (total: ${rescuerClients.size})`);
            console.log(`📋 All online rescuers: [${[...rescuerClients.keys()].join(', ')}]`);

            ws.on('close', () => {
                rescuerClients.delete(normalisedId);
                console.log(`⬇️  Rescuer offline: ${normalisedId}`);
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

// Broadcast SOS to specific rescuer IDs (called from dispatch.js)
// Falls back to broadcast-all if no specific IDs match (GPS not yet pinged)
export function broadcastToRescuers(rescuerIds, payload) {
    const message = JSON.stringify(payload);
    let sent = 0;

    // Normalise all IDs to lowercase before lookup
    const normalisedIds = rescuerIds.map(id => id.toLowerCase());

    console.log(`📡 Attempting broadcast to ${normalisedIds.length} rescuer(s): [${normalisedIds.join(', ')}]`);
    console.log(`📋 Currently connected rescuers: [${[...rescuerClients.keys()].join(', ')}]`);

    normalisedIds.forEach(id => {
        const ws = rescuerClients.get(id);
        if (ws?.readyState === 1) {   // 1 = OPEN
            ws.send(message);
            sent++;
            console.log(`   ✅ Sent to rescuer: ${id}`);
        } else {
            console.log(`   ⚠️  Rescuer ${id} not connected or WS not open (ws=${ws?.readyState})`);
        }
    });

    console.log(`📡 SOS broadcast result: ${sent}/${normalisedIds.length} rescuers reached via targeted dispatch`);

    // FALLBACK: If nobody was reached AND there are online rescuers, broadcast to ALL
    // This handles the case where a rescuer is online but hasn't posted GPS yet
    if (sent === 0 && rescuerClients.size > 0) {
        console.log(`⚠️  FALLBACK: No targeted rescuers reached. Broadcasting to ALL ${rescuerClients.size} online rescuers.`);
        rescuerClients.forEach((ws, id) => {
            if (ws.readyState === 1) {
                ws.send(message);
                sent++;
                console.log(`   📣 Fallback sent to: ${id}`);
            }
        });
        console.log(`📡 Fallback broadcast complete: ${sent} rescuers notified`);
    }
}

// Relay message to everyone in an incident room (called from routes)
export function broadcastToIncidentRoom(incidentId, payload) {
    const room = incidentRooms.get(incidentId);
    if (!room) {
        console.log(`⚠️  No incident room found for: ${incidentId}`);
        return;
    }
    const message = JSON.stringify(payload);
    let sent = 0;
    room.forEach(ws => {
        if (ws.readyState === 1) {
            ws.send(message);
            sent++;
        }
    });
    console.log(`📡 Incident room ${incidentId}: relayed to ${sent}/${room.size} members`);
}

// Exported for debugging — get count of online rescuers
export function getOnlineRescuerCount() {
    return rescuerClients.size;
}