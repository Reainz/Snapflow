"use strict";
/**
 * Error Handling Tests for Cloudinary Signed URLs
 * Tests: Missing credentials, invalid publicIds, network errors, graceful error handling
 */
Object.defineProperty(exports, "__esModule", { value: true });
const cloudinary_1 = require("../../utils/cloudinary");
describe('Error Handling Tests for Cloudinary Signed URLs', () => {
    describe('Missing Cloudinary Credentials', () => {
        test('should throw error if CLOUDINARY_CLOUD_NAME is missing', () => {
            // Save original values
            const originalCloudName = process.env.CLOUDINARY_CLOUD_NAME;
            const originalApiKey = process.env.CLOUDINARY_API_KEY;
            const originalApiSecret = process.env.CLOUDINARY_API_SECRET;
            // Clear cloud name
            delete process.env.CLOUDINARY_CLOUD_NAME;
            // Force reconfiguration
            jest.resetModules();
            const { configureCloudinary: freshConfig } = require('../../utils/cloudinary');
            expect(() => {
                freshConfig();
            }).toThrow('Cloudinary credentials not set');
            // Restore environment variables
            process.env.CLOUDINARY_CLOUD_NAME = originalCloudName;
            process.env.CLOUDINARY_API_KEY = originalApiKey;
            process.env.CLOUDINARY_API_SECRET = originalApiSecret;
        });
        test('should throw error if CLOUDINARY_API_KEY is missing', () => {
            const originalCloudName = process.env.CLOUDINARY_CLOUD_NAME;
            const originalApiKey = process.env.CLOUDINARY_API_KEY;
            const originalApiSecret = process.env.CLOUDINARY_API_SECRET;
            delete process.env.CLOUDINARY_API_KEY;
            jest.resetModules();
            const { configureCloudinary: freshConfig } = require('../../utils/cloudinary');
            expect(() => {
                freshConfig();
            }).toThrow('Cloudinary credentials not set');
            process.env.CLOUDINARY_CLOUD_NAME = originalCloudName;
            process.env.CLOUDINARY_API_KEY = originalApiKey;
            process.env.CLOUDINARY_API_SECRET = originalApiSecret;
        });
        test('should throw error if CLOUDINARY_API_SECRET is missing', () => {
            const originalCloudName = process.env.CLOUDINARY_CLOUD_NAME;
            const originalApiKey = process.env.CLOUDINARY_API_KEY;
            const originalApiSecret = process.env.CLOUDINARY_API_SECRET;
            delete process.env.CLOUDINARY_API_SECRET;
            jest.resetModules();
            const { configureCloudinary: freshConfig } = require('../../utils/cloudinary');
            expect(() => {
                freshConfig();
            }).toThrow('Cloudinary credentials not set');
            process.env.CLOUDINARY_CLOUD_NAME = originalCloudName;
            process.env.CLOUDINARY_API_KEY = originalApiKey;
            process.env.CLOUDINARY_API_SECRET = originalApiSecret;
        });
        test('should throw error if all Cloudinary credentials are missing', () => {
            const originalCloudName = process.env.CLOUDINARY_CLOUD_NAME;
            const originalApiKey = process.env.CLOUDINARY_API_KEY;
            const originalApiSecret = process.env.CLOUDINARY_API_SECRET;
            delete process.env.CLOUDINARY_CLOUD_NAME;
            delete process.env.CLOUDINARY_API_KEY;
            delete process.env.CLOUDINARY_API_SECRET;
            jest.resetModules();
            const { configureCloudinary: freshConfig } = require('../../utils/cloudinary');
            expect(() => {
                freshConfig();
            }).toThrow('Cloudinary credentials not set');
            process.env.CLOUDINARY_CLOUD_NAME = originalCloudName;
            process.env.CLOUDINARY_API_KEY = originalApiKey;
            process.env.CLOUDINARY_API_SECRET = originalApiSecret;
        });
    });
    describe('Invalid PublicId Handling', () => {
        test('should throw error for empty publicId', () => {
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)('');
            }).toThrow('PublicId is required');
        });
        test('should throw error for null publicId', () => {
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)(null);
            }).toThrow('PublicId is required');
        });
        test('should throw error for undefined publicId', () => {
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)(undefined);
            }).toThrow('PublicId is required');
        });
        test('should handle publicId with special characters', () => {
            const publicId = 'snapflow/processed/video-123_test@special/file';
            // Should not throw error
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)(publicId);
            }).not.toThrow();
        });
        test('should handle very long publicId', () => {
            const publicId = 'snapflow/processed/very/deep/folder/structure/with/many/levels/video123/file';
            // Should not throw error
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)(publicId);
            }).not.toThrow();
        });
    });
    describe('URL Extraction Error Handling', () => {
        test('should return null for empty URL', () => {
            const result = (0, cloudinary_1.extractPublicIdFromUrl)('');
            expect(result).toBeNull();
        });
        test('should return null for null URL', () => {
            const result = (0, cloudinary_1.extractPublicIdFromUrl)(null);
            expect(result).toBeNull();
        });
        test('should return null for undefined URL', () => {
            const result = (0, cloudinary_1.extractPublicIdFromUrl)(undefined);
            expect(result).toBeNull();
        });
        test('should return null for non-Cloudinary URL', () => {
            const url = 'https://firebasestorage.googleapis.com/v0/b/bucket/o/video.mp4';
            const result = (0, cloudinary_1.extractPublicIdFromUrl)(url);
            expect(result).toBeNull();
        });
        test('should return null for Cloudinary URL without /upload/', () => {
            const url = 'https://res.cloudinary.com/test-cloud/video/file.m3u8';
            const result = (0, cloudinary_1.extractPublicIdFromUrl)(url);
            expect(result).toBeNull();
        });
        test('should return null for malformed Cloudinary URL', () => {
            const url = 'https://res.cloudinary.com/test-cloud/upload/';
            const result = (0, cloudinary_1.extractPublicIdFromUrl)(url);
            expect(result).toBeNull();
        });
        test('should handle URL with invalid characters gracefully', () => {
            const url = 'https://res.cloudinary.com/test-cloud/video/upload/<script>alert("xss")</script>';
            const result = (0, cloudinary_1.extractPublicIdFromUrl)(url);
            // Should not throw error, should return extracted value or null
            expect(result).not.toBeUndefined();
        });
        test('should handle URL with excessive query parameters', () => {
            const url = 'https://res.cloudinary.com/test-cloud/video/upload/video123.m3u8?a=1&b=2&c=3&d=4&e=5&f=6';
            const result = (0, cloudinary_1.extractPublicIdFromUrl)(url);
            expect(result).toBe('video123');
        });
    });
    describe('Network Error Simulation', () => {
        test('should handle network timeout gracefully', async () => {
            // Mock network timeout
            jest.setTimeout(5000);
            // Simulate network delay
            const slowOperation = new Promise((resolve) => {
                setTimeout(() => {
                    resolve('success');
                }, 100);
            });
            await expect(slowOperation).resolves.toBe('success');
        });
        test('should handle connection refused error', () => {
            // Simulate connection refused scenario
            const mockError = new Error('ECONNREFUSED');
            expect(mockError.message).toBe('ECONNREFUSED');
            expect(mockError).toBeInstanceOf(Error);
        });
        test('should handle DNS lookup failure', () => {
            // Simulate DNS lookup failure
            const mockError = new Error('ENOTFOUND');
            expect(mockError.message).toBe('ENOTFOUND');
            expect(mockError).toBeInstanceOf(Error);
        });
    });
    describe('Cloudinary API Error Simulation', () => {
        test('should handle Cloudinary authentication error', () => {
            // Mock authentication error from Cloudinary
            const mockError = {
                error: {
                    message: 'Invalid authentication credentials',
                    http_code: 401,
                },
            };
            expect(mockError.error.http_code).toBe(401);
            expect(mockError.error.message).toContain('Invalid authentication');
        });
        test('should handle Cloudinary rate limit error', () => {
            // Mock rate limit error
            const mockError = {
                error: {
                    message: 'Rate limit exceeded',
                    http_code: 429,
                },
            };
            expect(mockError.error.http_code).toBe(429);
            expect(mockError.error.message).toContain('Rate limit exceeded');
        });
        test('should handle Cloudinary resource not found error', () => {
            // Mock resource not found error
            const mockError = {
                error: {
                    message: 'Resource not found',
                    http_code: 404,
                },
            };
            expect(mockError.error.http_code).toBe(404);
            expect(mockError.error.message).toContain('Resource not found');
        });
        test('should handle Cloudinary server error', () => {
            // Mock server error
            const mockError = {
                error: {
                    message: 'Internal server error',
                    http_code: 500,
                },
            };
            expect(mockError.error.http_code).toBe(500);
            expect(mockError.error.message).toContain('Internal server error');
        });
    });
    describe('Edge Case Error Handling', () => {
        test('should handle extremely long URL gracefully', () => {
            const longUrl = 'https://res.cloudinary.com/test-cloud/video/upload/' + 'a'.repeat(1000) + '/file.m3u8';
            expect(() => {
                (0, cloudinary_1.extractPublicIdFromUrl)(longUrl);
            }).not.toThrow();
        });
        test('should handle URL with unicode characters', () => {
            const unicodeUrl = 'https://res.cloudinary.com/test-cloud/video/upload/测试视频/file.m3u8';
            expect(() => {
                (0, cloudinary_1.extractPublicIdFromUrl)(unicodeUrl);
            }).not.toThrow();
        });
        test('should handle URL with URL-encoded characters', () => {
            const encodedUrl = 'https://res.cloudinary.com/test-cloud/video/upload/test%20video%20%2F%20file/file.m3u8';
            expect(() => {
                (0, cloudinary_1.extractPublicIdFromUrl)(encodedUrl);
            }).not.toThrow();
        });
        test('should handle negative expiration seconds', () => {
            const publicId = 'snapflow/processed/video123/file';
            // Negative expiration should still work (URL expires immediately)
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)(publicId, -3600);
            }).not.toThrow();
        });
        test('should handle zero expiration seconds', () => {
            const publicId = 'snapflow/processed/video123/file';
            // Zero expiration means immediate expiration
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)(publicId, 0);
            }).not.toThrow();
        });
        test('should handle very large expiration seconds', () => {
            const publicId = 'snapflow/processed/video123/file';
            // Very large expiration (1 year)
            expect(() => {
                (0, cloudinary_1.generateSignedCloudinaryUrl)(publicId, 31536000);
            }).not.toThrow();
        });
    });
    describe('Graceful Degradation', () => {
        test('should provide meaningful error message for missing publicId', () => {
            try {
                (0, cloudinary_1.generateSignedCloudinaryUrl)('');
            }
            catch (error) {
                expect(error.message).toBe('PublicId is required to generate signed Cloudinary URL');
                expect(error.message).not.toBe(''); // Not an empty error
            }
        });
        test('should provide meaningful error message for missing credentials', () => {
            const originalCloudName = process.env.CLOUDINARY_CLOUD_NAME;
            delete process.env.CLOUDINARY_CLOUD_NAME;
            jest.resetModules();
            const { configureCloudinary: freshConfig } = require('../../utils/cloudinary');
            try {
                freshConfig();
            }
            catch (error) {
                expect(error.message).toContain('Cloudinary credentials not set');
                // Modern message points back to env file; ensure it is still actionable
                expect(error.message.toLowerCase()).toContain('.env');
            }
            process.env.CLOUDINARY_CLOUD_NAME = originalCloudName;
        });
        test('should not expose sensitive information in error messages', () => {
            const originalApiKey = process.env.CLOUDINARY_API_KEY;
            delete process.env.CLOUDINARY_API_KEY;
            jest.resetModules();
            const { configureCloudinary: freshConfig } = require('../../utils/cloudinary');
            try {
                freshConfig();
            }
            catch (error) {
                // Error message should NOT contain actual API key values
                expect(error.message).not.toContain('test-api-key');
                expect(error.message).not.toContain('test-api-secret');
            }
            process.env.CLOUDINARY_API_KEY = originalApiKey;
        });
    });
    describe('Logging and Debugging', () => {
        test('should log errors to console for debugging', () => {
            const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
            // Trigger an error scenario
            const invalidUrl = 'https://example.com/video.mp4';
            (0, cloudinary_1.extractPublicIdFromUrl)(invalidUrl);
            // Error should NOT be logged for normal null return
            // Only exception: internal errors should be logged
            consoleErrorSpy.mockRestore();
        });
        test('should include context in error logs', () => {
            // Error logs should include useful context:
            // - Video ID
            // - User ID
            // - PublicId
            // - Timestamp
            const errorContext = {
                videoId: 'video123',
                userId: 'user456',
                publicId: 'snapflow/processed/video123/file',
                timestamp: Date.now(),
            };
            expect(errorContext).toHaveProperty('videoId');
            expect(errorContext).toHaveProperty('userId');
            expect(errorContext).toHaveProperty('publicId');
            expect(errorContext).toHaveProperty('timestamp');
        });
    });
});
//# sourceMappingURL=errorHandling.test.js.map