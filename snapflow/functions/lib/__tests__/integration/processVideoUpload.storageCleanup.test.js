"use strict";
/**
 * Integration Tests for processVideoUpload Storage Cleanup
 *
 * CRITICAL SECURITY TESTS: Verify that processVideoUpload deletes rejected
 * files from Firebase Storage when rate limit is exceeded.
 *
 * This prevents storage bucket abuse attacks where attackers upload files
 * repeatedly after hitting rate limit to fill bucket and incur unlimited costs.
 *
 * Test Coverage:
 * 1. Storage bucket.file().delete() is called when rate limit exceeded
 * 2. Video status updated to 'failed' with RATE_LIMIT_EXCEEDED error code
 * 3. Delete continues even if storage deletion fails (fail-safe)
 * 4. Proper error messages with retry time formatting
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
// Mock Firebase Admin SDK
const mockDelete = jest.fn();
const mockFile = jest.fn(() => ({ delete: mockDelete }));
const mockBucket = jest.fn(() => ({ file: mockFile }));
const mockStorage = jest.fn(() => ({ bucket: mockBucket }));
const mockUpdateVideoStatus = jest.fn();
jest.mock('firebase-admin', () => ({
    apps: [],
    initializeApp: jest.fn(),
    storage: mockStorage,
    firestore: jest.fn(() => ({
        collection: jest.fn(),
    })),
    FieldValue: {
        serverTimestamp: jest.fn(() => ({ type: 'serverTimestamp' })),
    },
    Timestamp: {
        fromMillis: jest.fn((ms) => ({ toMillis: () => ms })),
    },
}));
// Mock rate limiter - must be set before importing processVideoUpload
const mockCheckRateLimit = jest.fn();
jest.mock('../../utils/rate-limiter', () => ({
    checkRateLimit: mockCheckRateLimit,
}));
// Mock firestore-helpers
jest.mock('../../utils/firestore-helpers', () => ({
    updateVideoStatus: mockUpdateVideoStatus,
    getDb: jest.fn(() => ({
        collection: jest.fn(() => ({
            doc: jest.fn(() => ({
                set: jest.fn(),
                get: jest.fn(),
            })),
        })),
    })),
}));
// Mock performance monitoring
jest.mock('../../utils/performance-monitoring', () => ({
    withPerformanceMonitoring: jest.fn((fn) => fn),
}));
// Mock cloudinary
jest.mock('../../utils/cloudinary', () => ({
    uploadVideoToCloudinary: jest.fn(),
}));
// Set up Firebase config for unit testing
process.env.FIREBASE_CONFIG = JSON.stringify({
    projectId: 'test-project',
    storageBucket: 'test-bucket',
});
describe('processVideoUpload - Storage Cleanup on Rate Limit', () => {
    let processVideoUpload;
    beforeAll(async () => {
        // Import after mocks are set up (module caching happens at describe level)
        const module = await Promise.resolve().then(() => __importStar(require('../../video/processVideoUpload')));
        processVideoUpload = module.processVideoUpload;
    });
    beforeEach(async () => {
        jest.clearAllMocks();
    });
    /**
     * CRITICAL TEST: Verifies that storage cleanup happens when rate limit exceeded
     */
    test('should delete file from Storage when rate limit exceeded', async () => {
        // Mock rate limiter to return rate limit exceeded
        mockCheckRateLimit.mockResolvedValue({
            allowed: false,
            remaining: 0,
            resetAt: Date.now() + 1800000, // 30 minutes from now
            retryAfterSeconds: 1800, // 30 minutes
        });
        // Create mock CloudEvent for video upload
        const mockEvent = {
            specversion: '1.0',
            id: 'test-event-123',
            source: 'storage.googleapis.com',
            type: 'google.cloud.storage.object.v1.finalized',
            time: new Date().toISOString(),
            data: {
                id: 'test-bucket/raw-videos/user123/video456.mp4/1',
                bucket: 'test-bucket',
                name: 'raw-videos/user123/video456.mp4',
                storageClass: 'STANDARD',
                contentType: 'video/mp4',
                size: 1000000,
                timeCreated: new Date().toISOString(),
                updated: new Date().toISOString(),
                md5Hash: 'test-hash',
                generation: 1,
                metageneration: 1,
            },
        };
        // Execute the function
        await processVideoUpload(mockEvent);
        // ASSERTION 1: Rate limit was checked
        expect(mockCheckRateLimit).toHaveBeenCalledWith('user123', 'upload');
        // ASSERTION 2: Storage bucket was accessed with correct bucket name
        expect(mockStorage).toHaveBeenCalled();
        expect(mockBucket).toHaveBeenCalledWith('test-bucket');
        // ASSERTION 3: File reference was obtained with correct path
        expect(mockFile).toHaveBeenCalledWith('raw-videos/user123/video456.mp4');
        // ASSERTION 4: Delete was called on the file
        expect(mockDelete).toHaveBeenCalled();
        // ASSERTION 5: Video status was updated to failed with RATE_LIMIT_EXCEEDED
        expect(mockUpdateVideoStatus).toHaveBeenCalledWith('video456', expect.objectContaining({
            status: 'failed',
            errorCode: 'RATE_LIMIT_EXCEEDED',
            error: expect.stringContaining('Rate limit exceeded'),
        }));
    });
    /**
     * TEST: Verifies retry time formatting (singular vs plural)
     */
    test('should format retry time correctly in error message', async () => {
        // Mock rate limiter to return 1 minute retry
        mockCheckRateLimit.mockResolvedValue({
            allowed: false,
            remaining: 0,
            resetAt: Date.now() + 60000,
            retryAfterSeconds: 61, // 61 seconds = 2 minutes when rounded
        });
        const mockEvent = {
            specversion: '1.0',
            id: 'test-event-124',
            source: 'storage.googleapis.com',
            type: 'google.cloud.storage.object.v1.finalized',
            time: new Date().toISOString(),
            data: {
                id: 'test-bucket/raw-videos/user123/video457.mp4/1',
                bucket: 'test-bucket',
                name: 'raw-videos/user123/video457.mp4',
                storageClass: 'STANDARD',
                contentType: 'video/mp4',
                size: 1000000,
                timeCreated: new Date().toISOString(),
                updated: new Date().toISOString(),
                md5Hash: 'test-hash',
                generation: 1,
                metageneration: 1,
            },
        };
        await processVideoUpload(mockEvent);
        // Check error message uses plural "minutes"
        expect(mockUpdateVideoStatus).toHaveBeenCalledWith('video457', expect.objectContaining({
            error: expect.stringContaining('2 minutes'),
        }));
    });
    /**
     * TEST: Verifies edge case - exactly 60 seconds shows as seconds, not minutes
     */
    test('should show 60 seconds as seconds (not converted to minutes)', async () => {
        // Mock rate limiter to return exactly 60 seconds
        mockCheckRateLimit.mockResolvedValue({
            allowed: false,
            remaining: 0,
            resetAt: Date.now() + 60000,
            retryAfterSeconds: 60,
        });
        const mockEvent = {
            specversion: '1.0',
            id: 'test-event-125',
            source: 'storage.googleapis.com',
            type: 'google.cloud.storage.object.v1.finalized',
            time: new Date().toISOString(),
            data: {
                id: 'test-bucket/raw-videos/user123/video458.mp4/1',
                bucket: 'test-bucket',
                name: 'raw-videos/user123/video458.mp4',
                storageClass: 'STANDARD',
                contentType: 'video/mp4',
                size: 1000000,
                timeCreated: new Date().toISOString(),
                updated: new Date().toISOString(),
                md5Hash: 'test-hash',
                generation: 1,
                metageneration: 1,
            },
        };
        await processVideoUpload(mockEvent);
        // Check error message shows "60 seconds" (not converted to minutes because condition is > 60, not >= 60)
        expect(mockUpdateVideoStatus).toHaveBeenCalledWith('video458', expect.objectContaining({
            error: expect.stringContaining('60 seconds'),
        }));
    });
    /**
     * CRITICAL TEST: Fail-safe behavior when storage deletion fails
     */
    test('should continue with status update even if storage deletion fails', async () => {
        // Mock rate limiter to return rate limit exceeded
        mockCheckRateLimit.mockResolvedValue({
            allowed: false,
            remaining: 0,
            resetAt: Date.now() + 1800000,
            retryAfterSeconds: 1800,
        });
        // Mock delete to throw error
        mockDelete.mockRejectedValue(new Error('Storage deletion failed'));
        const mockEvent = {
            specversion: '1.0',
            id: 'test-event-126',
            source: 'storage.googleapis.com',
            type: 'google.cloud.storage.object.v1.finalized',
            time: new Date().toISOString(),
            data: {
                id: 'test-bucket/raw-videos/user123/video459.mp4/1',
                bucket: 'test-bucket',
                name: 'raw-videos/user123/video459.mp4',
                storageClass: 'STANDARD',
                contentType: 'video/mp4',
                size: 1000000,
                timeCreated: new Date().toISOString(),
                updated: new Date().toISOString(),
                md5Hash: 'test-hash',
                generation: 1,
                metageneration: 1,
            },
        };
        // Should not throw error - fail-safe behavior
        await expect(processVideoUpload(mockEvent)).resolves.not.toThrow();
        // ASSERTION: Status update still happens despite delete failure
        expect(mockUpdateVideoStatus).toHaveBeenCalledWith('video459', expect.objectContaining({
            status: 'failed',
            errorCode: 'RATE_LIMIT_EXCEEDED',
        }));
    });
    /**
     * TEST: Verifies multiple rate-limited uploads all trigger cleanup
     */
    test('should delete files for multiple consecutive rate-limited uploads', async () => {
        // Mock rate limiter to always return rate limit exceeded
        mockCheckRateLimit.mockResolvedValue({
            allowed: false,
            remaining: 0,
            resetAt: Date.now() + 1800000,
            retryAfterSeconds: 1800,
        });
        // Create 3 different upload events
        const events = [
            {
                specversion: '1.0',
                id: 'test-event-201',
                source: 'storage.googleapis.com',
                type: 'google.cloud.storage.object.v1.finalized',
                time: new Date().toISOString(),
                data: {
                    id: 'test-bucket/raw-videos/user123/video501.mp4/1',
                    bucket: 'test-bucket',
                    name: 'raw-videos/user123/video501.mp4',
                    storageClass: 'STANDARD',
                    contentType: 'video/mp4',
                    size: 1000000,
                    timeCreated: new Date().toISOString(),
                    updated: new Date().toISOString(),
                    md5Hash: 'test-hash-1',
                    generation: 1,
                    metageneration: 1,
                },
            },
            {
                specversion: '1.0',
                id: 'test-event-202',
                source: 'storage.googleapis.com',
                type: 'google.cloud.storage.object.v1.finalized',
                time: new Date().toISOString(),
                data: {
                    id: 'test-bucket/raw-videos/user123/video502.mp4/1',
                    bucket: 'test-bucket',
                    name: 'raw-videos/user123/video502.mp4',
                    storageClass: 'STANDARD',
                    contentType: 'video/mp4',
                    size: 1000000,
                    timeCreated: new Date().toISOString(),
                    updated: new Date().toISOString(),
                    md5Hash: 'test-hash-2',
                    generation: 1,
                    metageneration: 1,
                },
            },
            {
                specversion: '1.0',
                id: 'test-event-203',
                source: 'storage.googleapis.com',
                type: 'google.cloud.storage.object.v1.finalized',
                time: new Date().toISOString(),
                data: {
                    id: 'test-bucket/raw-videos/user123/video503.mp4/1',
                    bucket: 'test-bucket',
                    name: 'raw-videos/user123/video503.mp4',
                    storageClass: 'STANDARD',
                    contentType: 'video/mp4',
                    size: 1000000,
                    timeCreated: new Date().toISOString(),
                    updated: new Date().toISOString(),
                    md5Hash: 'test-hash-3',
                    generation: 1,
                    metageneration: 1,
                },
            },
        ];
        // Process all 3 uploads
        for (const event of events) {
            await processVideoUpload(event);
        }
        // ASSERTION: Delete was called 3 times (once for each rejected upload)
        expect(mockDelete).toHaveBeenCalledTimes(3);
        // ASSERTION: All 3 videos got failure status updates
        expect(mockUpdateVideoStatus).toHaveBeenCalledTimes(3);
        expect(mockUpdateVideoStatus).toHaveBeenNthCalledWith(1, 'video501', expect.objectContaining({ status: 'failed', errorCode: 'RATE_LIMIT_EXCEEDED' }));
        expect(mockUpdateVideoStatus).toHaveBeenNthCalledWith(2, 'video502', expect.objectContaining({ status: 'failed', errorCode: 'RATE_LIMIT_EXCEEDED' }));
        expect(mockUpdateVideoStatus).toHaveBeenNthCalledWith(3, 'video503', expect.objectContaining({ status: 'failed', errorCode: 'RATE_LIMIT_EXCEEDED' }));
    });
    /**
     * TEST: Verifies only raw-videos trigger rate limit check and cleanup
     */
    test('should not trigger cleanup for non-raw-video files', async () => {
        // Mock rate limiter (should not be called for non-raw uploads)
        mockCheckRateLimit.mockResolvedValue({
            allowed: false,
            remaining: 0,
            resetAt: Date.now() + 1800000,
            retryAfterSeconds: 1800,
        });
        // Create event for non-raw video (e.g., thumbnail)
        const mockEvent = {
            specversion: '1.0',
            id: 'test-event-301',
            source: 'storage.googleapis.com',
            type: 'google.cloud.storage.object.v1.finalized',
            time: new Date().toISOString(),
            data: {
                id: 'test-bucket/thumbnails/video123.jpg/1',
                bucket: 'test-bucket',
                name: 'thumbnails/video123.jpg', // Not in raw-videos/
                storageClass: 'STANDARD',
                contentType: 'image/jpeg',
                size: 100000,
                timeCreated: new Date().toISOString(),
                updated: new Date().toISOString(),
                md5Hash: 'test-hash',
                generation: 1,
                metageneration: 1,
            },
        };
        await processVideoUpload(mockEvent);
        // ASSERTION: Rate limit check was NOT called (early exit for non-raw uploads)
        expect(mockCheckRateLimit).not.toHaveBeenCalled();
        // ASSERTION: Delete was NOT called
        expect(mockDelete).not.toHaveBeenCalled();
        // ASSERTION: Status update was NOT called
        expect(mockUpdateVideoStatus).not.toHaveBeenCalled();
    });
});
//# sourceMappingURL=processVideoUpload.storageCleanup.test.js.map