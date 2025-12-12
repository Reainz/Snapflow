/**
 * Unit Tests for Cloudinary Utilities
 * Tests: isCloudinaryUrl(), extractPublicIdFromUrl(), generateSignedCloudinaryUrl()
 */

import {
  isCloudinaryUrl,
  extractPublicIdFromUrl,
  generateSignedCloudinaryUrl,
  configureCloudinary,
} from '../../utils/cloudinary';

describe('Cloudinary Utilities - Unit Tests', () => {
  
  describe('isCloudinaryUrl()', () => {
    
    test('should return true for standard Cloudinary URL', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/v1234567890/video.m3u8';
      expect(isCloudinaryUrl(url)).toBe(true);
    });
    
    test('should return true for Cloudinary URL with cloud name', () => {
      const url = 'https://res.cloudinary.com/dbiyyg49v/video/upload/snapflow/processed/video123/file.m3u8';
      expect(isCloudinaryUrl(url)).toBe(true);
    });
    
    test('should return true for Cloudinary URL with transformations', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/w_640,h_360/snapflow/processed/video123/file.m3u8';
      expect(isCloudinaryUrl(url)).toBe(true);
    });
    
    test('should return false for Firebase Storage URL', () => {
      const url = 'https://firebasestorage.googleapis.com/v0/b/bucket/o/video.mp4';
      expect(isCloudinaryUrl(url)).toBe(false);
    });
    
    test('should return false for non-Cloudinary URL', () => {
      const url = 'https://example.com/video.mp4';
      expect(isCloudinaryUrl(url)).toBe(false);
    });
    
    test('should return false for empty string', () => {
      expect(isCloudinaryUrl('')).toBe(false);
    });
    
    test('should return false for null/undefined input', () => {
      expect(isCloudinaryUrl(null as any)).toBe(false);
      expect(isCloudinaryUrl(undefined as any)).toBe(false);
    });
    
  });
  
  describe('extractPublicIdFromUrl()', () => {
    
    test('should extract publicId from simple Cloudinary URL', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/video123.m3u8';
      expect(extractPublicIdFromUrl(url)).toBe('video123');
    });
    
    test('should extract publicId with version', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/v1234567890/video123.m3u8';
      expect(extractPublicIdFromUrl(url)).toBe('video123');
    });
    
    test('should extract publicId with folder structure', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/snapflow/processed/video123/file.m3u8';
      expect(extractPublicIdFromUrl(url)).toBe('snapflow/processed/video123/file');
    });
    
    test('should extract publicId with version and folder', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/v1234567890/snapflow/processed/video123/file.m3u8';
      expect(extractPublicIdFromUrl(url)).toBe('snapflow/processed/video123/file');
    });
    
    test('should extract publicId with transformations', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/w_640,h_360,c_fill/snapflow/processed/video123/file.m3u8';
      expect(extractPublicIdFromUrl(url)).toBe('snapflow/processed/video123/file');
    });
    
    test('should extract publicId with query parameters', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/snapflow/processed/video123/file.m3u8?token=abc123';
      expect(extractPublicIdFromUrl(url)).toBe('snapflow/processed/video123/file');
    });
    
    test('should extract publicId with complex transformations and version', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/v1234567890/w_640,h_360,c_fill/snapflow/processed/video123/file.m3u8';
      expect(extractPublicIdFromUrl(url)).toBe('snapflow/processed/video123/file');
    });
    
    test('should return null for non-Cloudinary URL', () => {
      const url = 'https://firebasestorage.googleapis.com/v0/b/bucket/o/video.mp4';
      expect(extractPublicIdFromUrl(url)).toBeNull();
    });
    
    test('should return null for empty string', () => {
      expect(extractPublicIdFromUrl('')).toBeNull();
    });
    
    test('should return null for URL without /upload/', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/video123.m3u8';
      expect(extractPublicIdFromUrl(url)).toBeNull();
    });
    
    test('should handle URL with multiple dots in filename', () => {
      const url = 'https://res.cloudinary.com/test-cloud/video/upload/snapflow/processed/video.test.123/file.name.m3u8';
      expect(extractPublicIdFromUrl(url)).toBe('snapflow/processed/video.test.123/file.name');
    });
    
  });
  
  describe('generateSignedCloudinaryUrl()', () => {
    
    // Mock cloudinary.url to avoid actual API calls
    jest.mock('cloudinary', () => ({
      v2: {
        config: jest.fn(),
        url: jest.fn((publicId, options) => {
          // Return a mock signed URL
          return `https://res.cloudinary.com/test-cloud/video/upload/s--signature--/exp_${options.expires_at}/${publicId}.m3u8`;
        }),
      },
    }));
    
    beforeEach(() => {
      // Reset configuration state
      jest.clearAllMocks();
    });
    
    test('should generate signed URL with default expiration (1 hour)', () => {
      const publicId = 'snapflow/processed/video123/file';
      const signedUrl = generateSignedCloudinaryUrl(publicId);
      
      expect(signedUrl).toBeDefined();
      expect(typeof signedUrl).toBe('string');
      expect(signedUrl.length).toBeGreaterThan(0);
    });
    
    test('should generate signed URL with custom expiration', () => {
      const publicId = 'snapflow/processed/video123/file';
      const expirationSeconds = 7200; // 2 hours
      const signedUrl = generateSignedCloudinaryUrl(publicId, expirationSeconds);
      
      expect(signedUrl).toBeDefined();
      expect(typeof signedUrl).toBe('string');
    });
    
    test('should throw error for empty publicId', () => {
      expect(() => {
        generateSignedCloudinaryUrl('');
      }).toThrow('PublicId is required');
    });
    
    test('should throw error for null publicId', () => {
      expect(() => {
        generateSignedCloudinaryUrl(null as any);
      }).toThrow('PublicId is required');
    });
    
    test('should generate different URLs for different publicIds', () => {
      const publicId1 = 'snapflow/processed/video123/file';
      const publicId2 = 'snapflow/processed/video456/file';
      
      const url1 = generateSignedCloudinaryUrl(publicId1);
      const url2 = generateSignedCloudinaryUrl(publicId2);
      
      expect(url1).not.toBe(url2);
    });
    
  });
  
  describe('configureCloudinary()', () => {
    
    test('should configure Cloudinary with environment variables', () => {
      expect(() => {
        configureCloudinary();
      }).not.toThrow();
    });
    
    test('should throw error if environment variables are missing', () => {
      // Save original values
      const originalCloudName = process.env.CLOUDINARY_CLOUD_NAME;
      const originalApiKey = process.env.CLOUDINARY_API_KEY;
      const originalApiSecret = process.env.CLOUDINARY_API_SECRET;
      
      // Clear environment variables
      delete process.env.CLOUDINARY_CLOUD_NAME;
      delete process.env.CLOUDINARY_API_KEY;
      delete process.env.CLOUDINARY_API_SECRET;
      
      // Should throw error
      expect(() => {
        // Force reconfiguration by clearing module cache
        jest.resetModules();
        const { configureCloudinary: freshConfig } = require('../../utils/cloudinary');
        freshConfig();
      }).toThrow('Cloudinary credentials not set');
      
      // Restore environment variables
      process.env.CLOUDINARY_CLOUD_NAME = originalCloudName;
      process.env.CLOUDINARY_API_KEY = originalApiKey;
      process.env.CLOUDINARY_API_SECRET = originalApiSecret;
    });
    
  });
  
});
