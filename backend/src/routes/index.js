import { Router } from 'express';
import authRoutes from './auth.js';
import incidentRoutes from './incidents.js';
import rescuerRoutes from './rescuers.js';
import uploadRoutes from './upload.js';

const router = Router();

router.use('/auth', authRoutes);
router.use('/incidents', incidentRoutes);
router.use('/rescuers', rescuerRoutes);
router.use('/upload', uploadRoutes);

// Health check
router.get('/health', (req, res) => res.json({
    status: 'ok',
    timestamp: new Date().toISOString()
}));

export default router;