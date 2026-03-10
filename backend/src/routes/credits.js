import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { getTotalCredits, getCreditHistory, deriveTier } from '../services/credits.js';

const router = Router();

// GET /credits/me — rescuer's total credits + tier
router.get('/me', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        console.log('🏅 [Credits Route] GET /credits/me for', req.user.id);

        const totalCredits = await getTotalCredits(req.user.id);
        const tier = deriveTier(totalCredits);

        res.json({
            totalCredits,
            tier: tier.name,
            tierBadge: tier.badge,
        });
    } catch (err) {
        console.error('❌ [Credits Route] Error:', err);
        next(err);
    }
});

// GET /credits/history — rescuer's credit transaction history
router.get('/history', requireAuth, requireRole('rescuer'), async (req, res, next) => {
    try {
        console.log('🏅 [Credits Route] GET /credits/history for', req.user.id);

        const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
        const history = await getCreditHistory(req.user.id, limit);

        res.json({ history });
    } catch (err) {
        console.error('❌ [Credits Route] Error:', err);
        next(err);
    }
});

export default router;
