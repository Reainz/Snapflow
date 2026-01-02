"use strict";
/**
 * Unit Tests for Rate Limiter Utility
 * Tests: checkRateLimit(), bucket generation, TTL, transactions, edge cases
 */
Object.defineProperty(exports, "__esModule", { value: true });
const rate_limiter_1 = require("../../utils/rate-limiter");
// Mock Firebase Admin
jest.mock('firebase-admin', () => {
    const firestoreMock = jest.fn(() => ({
        collection: jest.fn(),
    }));
    // Attach static properties on the firestore namespace to mirror the real SDK
    firestoreMock.FieldValue = {
        serverTimestamp: jest.fn(() => ({ type: 'serverTimestamp' })),
    };
    firestoreMock.Timestamp = {
        fromMillis: jest.fn((ms) => ({ toMillis: () => ms })),
    };
    return {
        apps: [],
        initializeApp: jest.fn(),
        firestore: firestoreMock,
    };
});
jest.mock('../../utils/firestore-helpers', () => ({
    getDb: jest.fn(),
}));
jest.mock('firebase-functions', () => ({
    logger: {
        error: jest.fn(),
        warn: jest.fn(),
        info: jest.fn(),
        debug: jest.fn(),
    },
}));
describe('Rate Limiter - Unit Tests', () => {
    let mockTransaction;
    let mockDocRef;
    let mockDb;
    let transactionState; // Internal state for transaction
    beforeEach(() => {
        jest.clearAllMocks();
        // Initialize transaction state
        transactionState = {};
        // Setup mock transaction with internal state tracking
        mockTransaction = {
            get: jest.fn(async (docRef) => {
                const docId = docRef.id;
                const docData = transactionState[docId];
                return {
                    exists: docData !== undefined,
                    data: () => docData,
                };
            }),
            set: jest.fn((docRef, data, options) => {
                const docId = docRef.id;
                // Update transaction state to simulate Firestore write
                if (options?.merge) {
                    transactionState[docId] = transactionState[docId]
                        ? { ...transactionState[docId], ...data }
                        : data;
                }
                else {
                    transactionState[docId] = data;
                }
            }),
        };
        // Setup mock document reference
        mockDocRef = {
            id: 'testUser123',
        };
        // Setup mock database
        mockDb = {
            collection: jest.fn(() => ({
                doc: jest.fn(() => mockDocRef),
            })),
            runTransaction: jest.fn(async (callback) => {
                // Don't reset state here - let each test manage it
                return await callback(mockTransaction);
            }),
        };
        const { getDb } = require('../../utils/firestore-helpers');
        getDb.mockReturnValue(mockDb);
    });
    describe('Successful Rate Limit Checks', () => {
        test('should allow first upload within limit', async () => {
            // Mock: no existing rate limit document (transactionState starts empty)
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(true);
            // When no document exists, count starts at 0, increments to 1, so remaining = 5 - 1 = 4
            expect(result.remaining).toBe(4);
            expect(mockTransaction.set).toHaveBeenCalled();
            // Verify the set was called with count = 1
            const setCall = mockTransaction.set.mock.calls[0];
            expect(setCall[1].upload.count).toBe(1);
        });
        test('should allow upload within hourly limit', async () => {
            // Generate correct bucket format: YYYY-MM-DD-HH (with dashes, no T)
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hour = String(now.getUTCHours()).padStart(2, '0');
            const currentBucket = `${year}-${month}-${day}-${hour}`;
            // Mock: existing document with 2 uploads in current bucket
            // Set initial state before transaction runs
            transactionState['testUser123'] = {
                userId: 'testUser123',
                upload: {
                    count: 2,
                    bucket: currentBucket,
                    resetAt: Date.now() + 3600000,
                },
            };
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(true);
            expect(result.remaining).toBe(2); // 5 - 3 (after increment: 2 + 1 = 3) = 2
        });
        test('should reset counter when bucket changes', async () => {
            const oldBucket = '2025-11-09-10';
            const currentTime = new Date('2025-11-09T11:30:00Z');
            jest.useFakeTimers();
            jest.setSystemTime(currentTime);
            // Mock: existing document with old bucket
            transactionState['testUser123'] = {
                userId: 'testUser123',
                upload: {
                    count: 5, // Was at limit
                    bucket: oldBucket,
                    resetAt: currentTime.getTime() - 1000,
                },
            };
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(true);
            expect(result.remaining).toBe(4); // Reset to 0, then increment to 1, so 5 - 1 = 4
            jest.useRealTimers();
        });
    });
    describe('Rate Limit Exceeded', () => {
        test('should block upload when limit reached', async () => {
            // Generate correct bucket format: YYYY-MM-DD-HH
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hour = String(now.getUTCHours()).padStart(2, '0');
            const currentBucket = `${year}-${month}-${day}-${hour}`;
            const resetAt = Date.now() + 1800000; // 30 minutes
            // Mock: existing document at upload limit
            transactionState['testUser123'] = {
                userId: 'testUser123',
                upload: {
                    count: 5, // At limit
                    bucket: currentBucket,
                    resetAt,
                },
            };
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(false);
            expect(result.remaining).toBe(0);
            expect(result.retryAfterSeconds).toBeDefined();
            expect(result.retryAfterSeconds).toBeGreaterThan(0);
            expect(mockTransaction.set).not.toHaveBeenCalled();
        });
        test('should calculate correct retry time', async () => {
            // Generate correct bucket format: YYYY-MM-DD-HH
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hour = String(now.getUTCHours()).padStart(2, '0');
            const currentBucket = `${year}-${month}-${day}-${hour}`;
            // Calculate resetAt based on next hour boundary (implementation behavior)
            const nextHour = new Date(now);
            nextHour.setUTCHours(nextHour.getUTCHours() + 1, 0, 0, 0);
            const resetAt = nextHour.getTime();
            transactionState['testUser123'] = {
                userId: 'testUser123',
                comment: {
                    count: 20, // At limit
                    bucket: currentBucket,
                    resetAt,
                },
            };
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'comment');
            expect(result.allowed).toBe(false);
            // Retry time should be close to the time until next hour
            const expectedRetry = Math.ceil((resetAt - Date.now()) / 1000);
            expect(result.retryAfterSeconds).toBeCloseTo(expectedRetry, -2);
        });
    });
    describe('Different Actions', () => {
        test('should apply correct limits for each action type', async () => {
            const actions = ['upload', 'comment', 'like', 'follow', 'share', 'flag'];
            const expectedLimits = {
                upload: 5,
                comment: 20,
                like: 100,
                follow: 30,
                share: 50,
                flag: 10,
            };
            for (const action of actions) {
                // Reset transaction state for each action
                transactionState = {};
                const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', action);
                expect(result.allowed).toBe(true);
                expect(result.remaining).toBe(expectedLimits[action] - 1);
            }
        });
        test('should use daily bucket for flag action', async () => {
            const dailyBucket = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
            // Transaction state starts empty
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'flag');
            expect(result.allowed).toBe(true);
            expect(result.remaining).toBe(9); // 10 - 1 (after increment) = 9
            // Verify set was called with daily bucket format
            const setCall = mockTransaction.set.mock.calls[0];
            expect(setCall[1].flag.bucket).toMatch(/^\d{4}-\d{2}-\d{2}$/);
        });
    });
    describe('Error Handling', () => {
        test('should fail open when transaction fails', async () => {
            mockDb.runTransaction.mockRejectedValue(new Error('Transaction failed'));
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(true); // Fail open
            expect(result.remaining).toBe(5);
        });
        test('should fail open when database is unavailable', async () => {
            const { getDb } = require('../../utils/firestore-helpers');
            getDb.mockReturnValue({
                collection: jest.fn(() => ({
                    doc: jest.fn(() => mockDocRef),
                })),
                runTransaction: jest.fn(async () => {
                    throw new Error('Database unavailable');
                }),
            });
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(true); // Fail open
            expect(result.remaining).toBe(5); // Full limit when failing open
        });
    });
    describe('Concurrent Requests', () => {
        test('should handle concurrent rate limit checks with transactions', async () => {
            // Generate correct bucket format: YYYY-MM-DD-HH
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hour = String(now.getUTCHours()).padStart(2, '0');
            const currentBucket = `${year}-${month}-${day}-${hour}`;
            let callCount = 0;
            mockTransaction.get.mockImplementation(async (docRef) => {
                callCount++;
                const docId = docRef.id;
                transactionState[docId] = {
                    userId: 'testUser123',
                    upload: {
                        count: callCount - 1,
                        bucket: currentBucket,
                        resetAt: Date.now() + 3600000,
                    },
                };
                return {
                    exists: true,
                    data: () => transactionState[docId],
                };
            });
            const promises = Array(3).fill(null).map(() => (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload'));
            const results = await Promise.all(promises);
            // All should be allowed (within limit of 5)
            results.forEach(result => {
                expect(result.allowed).toBe(true);
            });
        });
    });
    describe('Storage Cleanup on Rate Limit (Integration Test)', () => {
        test('should verify rate limit rejection workflow', async () => {
            // Generate correct bucket format: YYYY-MM-DD-HH
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hour = String(now.getUTCHours()).padStart(2, '0');
            const currentBucket = `${year}-${month}-${day}-${hour}`;
            // Mock: User has already uploaded 5 videos (at limit)
            transactionState['testUser123'] = {
                userId: 'testUser123',
                upload: {
                    count: 5,
                    bucket: currentBucket,
                    resetAt: Date.now() + 3600000,
                },
            };
            // Attempt 6th upload - should be rejected
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(false);
            expect(result.remaining).toBe(0);
            expect(result.retryAfterSeconds).toBeGreaterThan(0);
            // Verify counter was NOT incremented (stayed at 5)
            const finalState = transactionState['testUser123'];
            expect(finalState.upload.count).toBe(5);
        });
        test('should calculate correct retry time when limit exceeded', async () => {
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hour = String(now.getUTCHours()).padStart(2, '0');
            const currentBucket = `${year}-${month}-${day}-${hour}`;
            // Mock: User at limit
            transactionState['testUser123'] = {
                userId: 'testUser123',
                upload: {
                    count: 5,
                    bucket: currentBucket,
                    resetAt: Date.now() + 1800000, // 30 minutes from now
                },
            };
            const result = await (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload');
            expect(result.allowed).toBe(false);
            // Allow some clock drift; any positive retry window under an hour is acceptable
            expect(result.retryAfterSeconds).toBeGreaterThan(0);
            expect(result.retryAfterSeconds).toBeLessThanOrEqual(3600);
        });
        test('should handle multiple consecutive rate limit violations', async () => {
            const now = new Date();
            const year = now.getUTCFullYear();
            const month = String(now.getUTCMonth() + 1).padStart(2, '0');
            const day = String(now.getUTCDate()).padStart(2, '0');
            const hour = String(now.getUTCHours()).padStart(2, '0');
            const currentBucket = `${year}-${month}-${day}-${hour}`;
            // Mock: User at limit
            transactionState['testUser123'] = {
                userId: 'testUser123',
                upload: {
                    count: 5,
                    bucket: currentBucket,
                    resetAt: Date.now() + 3600000,
                },
            };
            // Multiple violation attempts
            const results = await Promise.all([
                (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload'),
                (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload'),
                (0, rate_limiter_1.checkRateLimit)('testUser123', 'upload'),
            ]);
            // All should be rejected
            results.forEach(result => {
                expect(result.allowed).toBe(false);
                expect(result.remaining).toBe(0);
            });
            // Counter should still be 5 (not incremented)
            expect(transactionState['testUser123'].upload.count).toBe(5);
        });
    });
});
//# sourceMappingURL=rateLimiter.test.js.map