/**
 * Unit Tests for flagVideo Callable Function
 * Tests: authentication, input validation, rate limiting, video flagging
 */

import * as functions from 'firebase-functions/v2/https';

// Mock dependencies before importing flagVideo
jest.mock('../../utils/rate-limiter', () => ({
  checkRateLimit: jest.fn(),
}));

jest.mock('../../utils/firestore-helpers', () => ({
  getDb: jest.fn(),
}));

jest.mock('firebase-functions/v1', () => ({
  logger: {
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    debug: jest.fn(),
  },
}));

jest.mock('firebase-admin', () => ({
  firestore: {
    FieldValue: {
      serverTimestamp: jest.fn(() => ({ type: 'serverTimestamp' })),
    },
  },
}));

// Mock functions.onCall to return the handler directly
jest.mock('firebase-functions/v2/https', () => ({
  HttpsError: class HttpsError extends Error {
    constructor(public code: string, message: string, public details?: any) {
      super(message);
      this.name = 'HttpsError';
    }
  },
  onCall: jest.fn((handler) => handler),
}));

// Import after mocking
import { flagVideo } from '../../video/flagVideo';

describe('flagVideo Callable Function - Unit Tests', () => {
  
  let mockDb: any;
  let mockCheckRateLimit: any;
  let mockLogger: any;
  
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Setup mock database
    mockDb = {
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          get: jest.fn(),
          update: jest.fn(),
        })),
        add: jest.fn(),
      })),
    };
    
    const { getDb } = require('../../utils/firestore-helpers');
    getDb.mockReturnValue(mockDb);
    
    const { checkRateLimit } = require('../../utils/rate-limiter');
    mockCheckRateLimit = checkRateLimit;
    
    const { logger } = require('firebase-functions/v1');
    mockLogger = logger;
  });
  
  describe('Authentication', () => {
    
    test('should throw unauthenticated error when user not logged in', async () => {
      const request = {
        auth: undefined,
        data: { videoId: 'video123' },
      };
      
      await expect(flagVideo(request as any, {} as any)).rejects.toThrow(
        expect.objectContaining({
          code: 'unauthenticated',
          message: 'User must be authenticated to flag videos',
        })
      );
      
      expect(mockCheckRateLimit).not.toHaveBeenCalled();
    });
    
    test('should allow authenticated user to proceed', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: true,
        remaining: 9,
        resetAt: Date.now() + 86400000,
      });
      
      const mockVideoDoc = {
        exists: true,
        data: () => ({ videoId: 'video123', status: 'ready' }),
      };
      
      mockDb.collection.mockImplementation((collectionName: string) => {
        if (collectionName === 'videos') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(mockVideoDoc),
              update: jest.fn(),
            })),
          };
        }
        if (collectionName === 'admin_alerts') {
          return {
            add: jest.fn(),
          };
        }
        return { doc: jest.fn(), add: jest.fn() };
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video123' },
      };
      
      const result: any = await flagVideo(request as any, {} as any);
      
      expect(result.success).toBe(true);
      expect(mockCheckRateLimit).toHaveBeenCalledWith('user123', 'flag');
    });
  });
  
  describe('Input Validation', () => {
    
    test('should throw invalid-argument when videoId is missing', async () => {
      const request = {
        auth: { uid: 'user123' },
        data: {},
      };
      
      await expect(flagVideo(request as any, {} as any)).rejects.toThrow(
        expect.objectContaining({
          code: 'invalid-argument',
          message: 'videoId is required and must be a string',
        })
      );
    });
    
    test('should throw invalid-argument when videoId is not a string', async () => {
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 123 },
      };
      
      await expect(flagVideo(request as any, {} as any)).rejects.toThrow(
        expect.objectContaining({
          code: 'invalid-argument',
          message: 'videoId is required and must be a string',
        })
      );
    });
    
    test('should accept valid videoId string', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: true,
        remaining: 9,
      });
      
      const mockVideoDoc = {
        exists: true,
        data: () => ({ videoId: 'video123', status: 'ready' }),
      };
      
      mockDb.collection.mockImplementation((collectionName: string) => {
        if (collectionName === 'videos') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(mockVideoDoc),
              update: jest.fn(),
            })),
          };
        }
        if (collectionName === 'admin_alerts') {
          return {
            add: jest.fn(),
          };
        }
        return { doc: jest.fn(), add: jest.fn() };
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video-abc-123' },
      };
      
      const result: any = await flagVideo(request as any, {} as any);
      
      expect(result.success).toBe(true);
    });
  });
  
  describe('Rate Limiting', () => {
    
    test('should throw failed-precondition when rate limit exceeded', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: false,
        remaining: 0,
        resetAt: Date.now() + 3600000,
        retryAfterSeconds: 3600,
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video123' },
      };
      
      await expect(flagVideo(request as any, {} as any)).rejects.toThrow(
        expect.objectContaining({
          code: 'failed-precondition',
          message: expect.stringContaining('Flag limit reached'),
        })
      );
      
      expect(mockLogger.warn).toHaveBeenCalled();
      expect(mockDb.collection().doc().update).not.toHaveBeenCalled();
    });
    
    test('should include retryAfterSeconds in error details', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: false,
        remaining: 0,
        retryAfterSeconds: 7200,
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video123' },
      };
      
      try {
        await flagVideo(request as any, {} as any);
        fail('Should have thrown error');
      } catch (error: any) {
        expect(error.details).toEqual({ retryAfterSeconds: 7200 });
      }
    });
    
    test('should allow flag when within rate limit', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: true,
        remaining: 5,
        resetAt: Date.now() + 86400000,
      });
      
      const mockVideoDoc = {
        exists: true,
        data: () => ({ videoId: 'video123', status: 'ready' }),
      };
      
      const mockUpdate = jest.fn();
      const mockAddAlert = jest.fn();
      
      mockDb.collection.mockImplementation((collectionName: string) => {
        if (collectionName === 'videos') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(mockVideoDoc),
              update: mockUpdate,
            })),
          };
        }
        if (collectionName === 'admin_alerts') {
          return {
            add: mockAddAlert,
          };
        }
        return { doc: jest.fn(), add: jest.fn() };
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video123' },
      };
      
      const result: any = await flagVideo(request as any, {} as any);
      
      expect(result.success).toBe(true);
      expect(mockUpdate).toHaveBeenCalledWith(expect.objectContaining({
        status: 'flagged',
        flaggedBy: 'user123',
      }));
    });
  });
  
  describe('Video Flagging', () => {
    
    test('should throw not-found when video does not exist', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: true,
        remaining: 9,
      });
      
      const mockVideoDoc = {
        exists: false,
      };
      
      mockDb.collection.mockImplementation((collectionName: string) => {
        if (collectionName === 'videos') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(mockVideoDoc),
            })),
          };
        }
        return { doc: jest.fn() };
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'nonexistent' },
      };
      
      await expect(flagVideo(request as any, {} as any)).rejects.toThrow(
        expect.objectContaining({
          code: 'not-found',
          message: expect.stringContaining('not found'),
        })
      );
    });
    
    test('should successfully flag existing video', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: true,
        remaining: 9,
      });
      
      const mockVideoDoc = {
        exists: true,
        data: () => ({ videoId: 'video123', status: 'ready' }),
      };
      
      const mockUpdate = jest.fn();
      const mockAddAlert = jest.fn();
      
      mockDb.collection.mockImplementation((collectionName: string) => {
        if (collectionName === 'videos') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(mockVideoDoc),
              update: mockUpdate,
            })),
          };
        }
        if (collectionName === 'admin_alerts') {
          return {
            add: mockAddAlert,
          };
        }
        return { doc: jest.fn(), add: jest.fn() };
      });
      
      const request = {
        auth: { uid: 'user456' },
        data: { videoId: 'video789' },
      };
      
      const result: any = await flagVideo(request as any, {} as any);
      
      expect(result.success).toBe(true);
      expect(result.message).toContain('flagged successfully');
      expect(mockUpdate).toHaveBeenCalledWith({
        status: 'flagged',
        flaggedAt: { type: 'serverTimestamp' },
        flaggedBy: 'user456',
        updatedAt: { type: 'serverTimestamp' },
      });
      expect(mockLogger.info).toHaveBeenCalled();
    });
    
    test('should create admin alert when video is flagged', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: true,
        remaining: 8,
      });
      
      const mockVideoDoc = {
        exists: true,
        data: () => ({ videoId: 'video123', status: 'ready' }),
      };
      
      const mockAddAlert = jest.fn();
      
      mockDb.collection.mockImplementation((collectionName: string) => {
        if (collectionName === 'videos') {
          return {
            doc: jest.fn(() => ({
              get: jest.fn().mockResolvedValue(mockVideoDoc),
              update: jest.fn(),
            })),
          };
        }
        if (collectionName === 'admin_alerts') {
          return {
            add: mockAddAlert,
          };
        }
        return { doc: jest.fn(), add: jest.fn() };
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video456' },
      };
      
      await flagVideo(request as any, {} as any);
      
      expect(mockAddAlert).toHaveBeenCalledWith(expect.objectContaining({
        type: 'content_flagged',
        action: 'flag',
        userId: 'user123',
        resourceId: 'video456',
        severity: 'info',
        acknowledged: false,
      }));
    });
  });
  
  describe('Error Handling', () => {
    
    test('should wrap non-HttpsError exceptions as internal errors', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: true,
        remaining: 9,
      });
      
      mockDb.collection.mockImplementation(() => {
        throw new Error('Database connection failed');
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video123' },
      };
      
      await expect(flagVideo(request as any, {} as any)).rejects.toThrow(
        expect.objectContaining({
          code: 'internal',
          message: 'Failed to flag video. Please try again later.',
        })
      );
      
      expect(mockLogger.error).toHaveBeenCalled();
    });
    
    test('should re-throw HttpsError as-is', async () => {
      mockCheckRateLimit.mockResolvedValue({
        allowed: false,
        remaining: 0,
        retryAfterSeconds: 3600,
      });
      
      const request = {
        auth: { uid: 'user123' },
        data: { videoId: 'video123' },
      };
      
      await expect(flagVideo(request as any, {} as any)).rejects.toThrow(
        expect.objectContaining({
          code: 'failed-precondition',
        })
      );
    });
  });
});