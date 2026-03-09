import { verifyTokenAndGetProfile } from '../services/auth.js';

// Verifies the Supabase JWT sent by the iOS app
// Attaches req.user = { id, email, role } on success
export async function requireAuth(req, res, next) {
    console.log('🔐 [Auth Middleware] Checking authorization...');
    console.log('   Headers:', req.headers);

    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
        console.log('❌ [Auth Middleware] Missing or invalid Authorization header');
        return res.status(401).json({ error: 'Missing auth token' });
    }

    const token = authHeader.split(' ')[1];
    console.log('🔑 [Auth Middleware] Token received:', token.substring(0, 20) + '...');

    try {
        const userProfile = await verifyTokenAndGetProfile(token);
        console.log('✅ [Auth Middleware] Token verified for user:', {
            id: userProfile.id,
            email: userProfile.email,
            role: userProfile.role
        });

        req.user = userProfile;
        next();
    } catch (err) {
        console.log('❌ [Auth Middleware] Token verification failed:', err.message);
        return res.status(401).json({ error: err.message });
    }
}

// Role guard — use after requireAuth
export function requireRole(...roles) {
    return (req, res, next) => {
        console.log('👮 [Role Guard] Checking role. Required:', roles, 'User has:', req.user?.role);

        if (!roles.includes(req.user?.role)) {
            console.log('❌ [Role Guard] Insufficient permissions');
            return res.status(403).json({ error: 'Insufficient permissions' });
        }

        console.log('✅ [Role Guard] Role check passed');
        next();
    };
}