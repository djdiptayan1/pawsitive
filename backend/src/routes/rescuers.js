import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { updateRescuerLocation, findNearbyRescuersWithLocation } from '../services/location.js';

const router = Router();

// POST /rescuers/location — rescuer pings GPS every 3s
// Body: { lat, lng, incidentId? (if on active rescue) }
router.post('/location', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        const { lat, lng, incidentId, eta } = req.body;

        if (!lat || !lng) {
            return res.status(400).json({ error: 'lat and lng required' });
        }

        await updateRescuerLocation(req.user.id, lat, lng, incidentId, eta);

        res.json({ ok: true });
    } catch (err) {
        next(err);
    }
});

// GET /rescuers/nearby?lat=X&lng=Y&radius=Z — citizen sees nearby available rescuers
router.get('/nearby', requireAuth, async (req, res, next) => {
    try {
        const { lat, lng, radius } = req.query;
        if (!lat || !lng) {
            return res.status(400).json({ error: 'lat and lng query params required' });
        }

        console.log(`🔍 [Nearby Rescuers Query]`);
        console.log(`   Citizen location: ${lat}, ${lng}`);
        console.log(`   Radius: ${radius || 10000}m`);

        const rescuers = await findNearbyRescuersWithLocation(
            parseFloat(lat), parseFloat(lng), parseFloat(radius) || 100000
        );

        console.log(`✅ [Nearby Rescuers] Found ${rescuers.length} rescuers`);
        for (const r of rescuers) {
            console.log(`   - ${r.full_name} @ (${r.lat}, ${r.lng}) - ${r.distance_meters}m away`);
        }

        res.json({ rescuers });
    } catch (err) {
        console.error('❌ [Nearby Rescuers] Error:', err.message);
        next(err);
    }
});

export default router;