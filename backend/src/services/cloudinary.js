import { v2 as cloudinary } from 'cloudinary';
import fs from 'fs';
import { ENV } from '../config/env.js';

cloudinary.config({
    cloud_name: ENV.CLOUDINARY_CLOUD_NAME,
    api_key: ENV.CLOUDINARY_API_KEY,
    api_secret: ENV.CLOUDINARY_API_SECRET
});

/**
 * Uploads a file buffer to Cloudinary
 * @param {Buffer} fileBuffer - Buffer of the file
 * @param {string} [folder="pawsitive"] - Folder in Cloudinary
 * @param {string} [filename] - Original filename (without extension preferred)
 * @returns {Promise<import('cloudinary').UploadApiResponse|null>}
 */
const uploadOnCloudinary = async (fileBuffer, folder = "pawsitive", filename, transformation = []) => {
    try {
        if (!fileBuffer) return null;

        // Sanitize filename if provided
        const publicId = filename
            ? filename.trim().replace(/\s+/g, '_').replace(/[^a-zA-Z0-9_]/g, '')
            : undefined;

        return new Promise((resolve, reject) => {
            const uploadStream = cloudinary.uploader.upload_stream(
                {
                    resource_type: "auto",
                    folder: folder,
                    public_id: publicId,
                    use_filename: true,
                    unique_filename: false,
                    overwrite: true,
                    invalidate: true
                },
                (error, result) => {
                    if (error) {
                        console.error("Error uploading to Cloudinary:", error);
                        reject(null);
                    } else {
                        console.log("File is uploaded on Cloudinary ", result.url);
                        resolve(result);
                    }
                }
            );

            uploadStream.end(fileBuffer);
        });

    } catch (error) {
        console.error("Error in uploadOnCloudinary:", error);
        return null;
    }
}

/**
 * Deletes a file from Cloudinary
 * @param {string} publicId - Public ID of the asset
 * @param {string} [resourceType="image"] - Resource type (image, video, raw)
 * @returns {Promise<import('cloudinary').DeleteApiResponse>}
 */
const deleteFromCloudinary = async (publicId, resourceType = "image") => {
    try {
        if (!publicId) return null;
        const response = await cloudinary.uploader.destroy(publicId, {
            resource_type: resourceType
        });

        return response;
    } catch (error) {
        console.error("Error deleting from Cloudinary:", error);
        return null;
    }
}

/**
 * Generates an optimized URL for a Cloudinary asset
 * @param {string} publicId - Public ID of the asset
 * @param {object} [options={}] - Additional transformation options
 * @returns {string}
 */
const getOptimizedUrl = (publicId, options = {}) => {
    try {
        if (!publicId) return null;

        return cloudinary.url(publicId, {
            fetch_format: 'auto',   // Auto format (WebP/AVIF etc)
            quality: 'auto',        // Auto quality balance
            gravity: 'auto',        // Auto gravity ()
            // dpr: 'auto',         // Auto Device Pixel Ratio
            // flags: ['progressive', 'strip_profile'], // Progressive loading + Remove metadata
            ...options
        });
    } catch (error) {
        console.error("Error generating Cloudinary URL:", error);
        return null;
    }
}

/**
 * Uploads a base64 encoded image to Cloudinary
 * @param {string} base64String - Data URI string (e.g., data:image/jpeg;base64,...)
 * @param {string} [folder="pawsitive"] - Folder in Cloudinary
 * @returns {Promise<import('cloudinary').UploadApiResponse|null>}
 */
const uploadBase64Image = async (base64String, folder = "pawsitive") => {
    try {
        if (!base64String) {
            console.log('⚠️ [Cloudinary] No base64 string provided');
            return null;
        }

        console.log('☁️ [Cloudinary] Uploading base64 image to folder:', folder);
        console.log('   Base64 length:', base64String.length);

        const response = await cloudinary.uploader.upload(base64String, {
            folder: folder,
            resource_type: "auto",
        });

        console.log('✅ [Cloudinary] Image uploaded successfully:', response.url);
        return response;
    } catch (error) {
        console.error('❌ [Cloudinary] Error in uploadBase64Image:', error);
        return null;
    }
}

export {
    uploadOnCloudinary,
    deleteFromCloudinary,
    getOptimizedUrl,
    uploadBase64Image
};