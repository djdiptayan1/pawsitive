import { Router } from 'express';
import { updateProfile, getProfile, updateAvatar } from '../services/auth.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadBase64Image } from '../services/cloudinary.js';

const router = Router();

// POST /auth/profile — Update user profile
// iOS sends: { fullName, role }
// Updates full_name + role in the users table
router.post('/profile', requireAuth, async (req, res, next) => {
    try {
        console.log('📝 [Auth Route] POST /auth/profile');
        console.log('   User:', req.user.id);
        console.log('   Body:', req.body);

        const { fullName, role } = req.body;

        if (!fullName || !role) {
            console.log('❌ [Auth Route] Missing required fields');
            return res.status(400).json({ error: 'fullName and role are required' });
        }

        const updatedUser = await updateProfile(req.user.id, fullName, role);

        console.log('✅ [Auth Route] Profile updated successfully');
        res.json({ user: updatedUser });
    } catch (err) {
        if (err.message === 'Invalid role') {
            console.log('❌ [Auth Route] Invalid role provided');
            return res.status(400).json({ error: err.message });
        }
        console.log('❌ [Auth Route] Error updating profile:', err);
        next(err);
    }
});

// GET /auth/me — Fetch own profile
router.get('/me', requireAuth, async (req, res, next) => {
    try {
        console.log('👤 [Auth Route] GET /auth/me');
        console.log('   User:', req.user.id);

        const userProfile = await getProfile(req.user.id);

        const response = { user: userProfile };
        console.log('✅ [Auth Route] Profile fetched successfully');
        console.log('📤 [Auth Route] Sending response:', JSON.stringify(response, null, 2));

        // Disable caching
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');

        res.json(response);
    } catch (err) {
        console.log('❌ [Auth Route] Error fetching profile:', err);
        next(err);
    }
});

// POST /auth/avatar — Upload a base64 avatar
router.post('/avatar', requireAuth, async (req, res, next) => {
    try {
        console.log('🖼️ [Auth Route] POST /auth/avatar');
        console.log('   User:', req.user.id);

        const { avatarBase64 } = req.body;

        if (!avatarBase64) {
            console.log('❌ [Auth Route] Missing avatarBase64');
            return res.status(400).json({ error: 'avatarBase64 is required' });
        }

        console.log('   Base64 length:', avatarBase64.length);

        // Upload to Cloudinary under the 'avatars' folder
        const uploadResult = await uploadBase64Image(avatarBase64, 'avatars');

        if (!uploadResult) {
            console.log('❌ [Auth Route] Cloudinary upload failed');
            return res.status(500).json({ error: 'Failed to upload image to Cloudinary' });
        }

        console.log('✅ [Auth Route] Image uploaded to Cloudinary:', uploadResult.secure_url);

        // Update user profile in Supabase
        const updatedUser = await updateAvatar(req.user.id, uploadResult.secure_url);

        console.log('✅ [Auth Route] Avatar updated successfully');
        res.json({ user: updatedUser, avatarUrl: uploadResult.secure_url });
    } catch (err) {
        console.log('❌ [Auth Route] Error uploading avatar:', err);
        next(err);
    }
});

export default router;