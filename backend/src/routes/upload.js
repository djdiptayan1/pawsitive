import { Router } from 'express';
import multer from 'multer';
import { requireAuth } from '../middleware/auth.js';
import { uploadOnCloudinary } from '../services/cloudinary.js';

const router = Router();
const storage = multer.memoryStorage();        // hold file in RAM, not disk
const upload = multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 },   // 10MB max
    fileFilter: (_, file, cb) => {
        if (file.mimetype.startsWith('image/')) cb(null, true);
        else cb(new Error('Only images allowed'));
    }
});

// POST /upload/photo — upload animal photo → Cloudinary
// Returns: { url } — permanent public CDN URL
router.post('/photo', requireAuth, upload.single('photo'), async (req, res, next) => {
    try {
        if (!req.file) return res.status(400).json({ error: 'No file provided' });

        const filename = `incident_${req.user.id}_${Date.now()}`;

        const result = await uploadOnCloudinary(
            req.file.buffer,
            'pawsitive_incidents', // specific folder in Cloudinary
            filename
        );

        if (!result) {
            throw new Error('Failed to upload image to Cloudinary');
        }

        res.json({ url: result.secure_url });
    } catch (err) {
        next(err);
    }
});

export default router;