import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { reportIncident, getPendingIncidents, getIncidentById, getIncidentsByReporter, getIncidentsByRescuer, getActiveIncidentForCitizen, getActiveRescueForRescuer, acceptIncidentAssignment, completeIncidentAssignment } from '../services/incident.js';

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
        const result = await completeIncidentAssignment(req.params.id, req.user.id);
        res.json(result);
    } catch (err) {
        next(err);
    }
});

export default router;