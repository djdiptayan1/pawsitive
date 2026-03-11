import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import {
    reportIncident,
    getPendingIncidents,
    getIncidentById,
    getIncidentsByReporter,
    getIncidentsByRescuer,
    getActiveIncidentForCitizen,
    getActiveRescueForRescuer,
    acceptIncidentAssignment,
    completeIncidentAssignment,
    getNearbyActiveIncidents,
    submitWitnessReport,
    getHeatmapPoints,
    listConditionLog,
    postConditionLog,
} from '../services/incident.js';
import { getLocationHistory } from '../services/location.js';

const router = Router();

// POST /incidents — citizen creates SOS
router.post('/', requireAuth, requireRole('citizen'), async (req, res, next) => {
    try {
        const { title, location_name, photoUrl, lat, lng, severity } = req.body;

        if (!title || !photoUrl || !lat || !lng || !severity) {
            return res.status(400).json({ error: 'title, photoUrl, lat, lng, severity are required' });
        }

        const incident = await reportIncident({
            reporterId: req.user.id,
            title,
            locationName: location_name || 'Unknown Location',
            photoUrl, lat, lng, severity,
        });

        res.status(201).json({ incident });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/my-reports — citizen's full incident history
router.get('/my-reports', requireAuth, async (req, res, next) => {
    try {
        const incidents = await getIncidentsByReporter(req.user.id);
        res.json({ incidents });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/active — citizen's currently active incident
router.get('/active', requireAuth, async (req, res, next) => {
    try {
        const incident = await getActiveIncidentForCitizen(req.user.id);
        res.json({ incident });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/nearby-active?lat=&lng=&radius= — active incidents for witness flow
router.get('/nearby-active', requireAuth, async (req, res, next) => {
    try {
        const { lat, lng, radius } = req.query;
        if (!lat || !lng) {
            return res.status(400).json({ error: 'lat and lng query params required' });
        }

        const incidents = await getNearbyActiveIncidents(
            parseFloat(lat),
            parseFloat(lng),
            parseFloat(radius) || 1500
        );

        res.json({ incidents });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/heatmap — lightweight incident intensity points
router.get('/heatmap', async (req, res, next) => {
    try {
        const limit = Math.min(parseInt(req.query.limit, 10) || 500, 1000);
        const points = await getHeatmapPoints(limit);
        res.json({ points });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/my-rescues — rescuer's full rescue history
router.get('/my-rescues', requireAuth, async (req, res, next) => {
    try {
        const incidents = await getIncidentsByRescuer(req.user.id);
        res.json({ incidents });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/my-active-rescue — rescuer's currently active rescue
router.get('/my-active-rescue', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        const incident = await getActiveRescueForRescuer(req.user.id);
        res.json({ incident });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/pending — rescuer sees job board
router.get('/pending', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        const incidents = await getPendingIncidents();
        res.json({ incidents });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/:id — detail view
router.get('/:id', requireAuth, async (req, res, next) => {
    try {
        const incident = await getIncidentById(req.params.id);
        res.json({ incident });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/:id/location-history — GPS trail for rescue replay
router.get('/:id/location-history', requireAuth, async (req, res, next) => {
    try {
        const points = await getLocationHistory(req.params.id);
        res.json({ points });
    } catch (err) {
        next(err);
    }
});

// GET /incidents/:id/condition-log — citizen + rescuer timeline feed
router.get('/:id/condition-log', requireAuth, async (req, res, next) => {
    try {
        const entries = await listConditionLog(req.params.id);
        res.json({ entries });
    } catch (err) {
        next(err);
    }
});

// POST /incidents/:id/condition-log — assigned rescuer stage update
router.post('/:id/condition-log', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        const { stage, note, photoUrl } = req.body;

        if (!stage) {
            return res.status(400).json({ error: 'stage is required' });
        }

        const entry = await postConditionLog({
            incidentId: req.params.id,
            rescuerId: req.user.id,
            stage,
            note,
            photoUrl,
        });

        res.status(201).json({ entry });
    } catch (err) {
        next(err);
    }
});

// POST /incidents/:id/witness — citizen confirms an existing nearby case
router.post('/:id/witness', requireAuth, requireRole('citizen'), async (req, res, next) => {
    try {
        const { severity } = req.body;
        const result = await submitWitnessReport(req.params.id, req.user.id, severity || 'Minor');
        res.json({ result });
    } catch (err) {
        if (err.message === 'Incident not found or no longer active') {
            return res.status(404).json({ error: err.message });
        }
        next(err);
    }
});

// PATCH /incidents/:id/accept — rescuer accepts (race-safe)
router.patch('/:id/accept', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        await acceptIncidentAssignment(req.params.id, req.user);
        res.json({ success: true });
    } catch (err) {
        if (err.message === 'Incident already claimed by another rescuer') {
            return res.status(409).json({ error: err.message });
        }
        next(err);
    }
});

// PATCH /incidents/:id/complete — rescuer marks job done
router.patch('/:id/complete', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        const { rescuePhotoUrl, dropOffType } = req.body;
        const allowedDropOffTypes = ['vet_hospital', 'ngo_shelter', 'treated_on_scene'];

        if (!rescuePhotoUrl) {
            return res.status(400).json({ error: 'Proof of rescue photo is required' });
        }

        if (dropOffType && !allowedDropOffTypes.includes(dropOffType)) {
            return res.status(400).json({
                error: 'dropOffType must be one of: vet_hospital, ngo_shelter, treated_on_scene'
            });
        }

        const result = await completeIncidentAssignment(req.params.id, req.user.id, rescuePhotoUrl, dropOffType);
        res.json(result);
    } catch (err) {
        next(err);
    }
});

export default router;