"use strict";
/**
 * Unit Tests for API Metrics Collection
 * Tests: collectAPIMetrics Cloud Function
 *
 * Coverage:
 * - MetricServiceClient mocking
 * - Firestore write verification
 * - Error handling
 * - Edge cases (zero invocations, missing data, division by zero)
 * - Data structure validation
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
const admin = __importStar(require("firebase-admin"));
const monitoring_1 = require("@google-cloud/monitoring");
// Mock @google-cloud/monitoring
jest.mock('@google-cloud/monitoring');
describe('collectAPIMetrics', () => {
    let mockAdd;
    let mockCollection;
    let mockFirestore;
    let mockListTimeSeries;
    let firestoreSpy;
    beforeEach(() => {
        jest.clearAllMocks();
        // Setup Firestore mocks using spyOn
        mockAdd = jest.fn().mockResolvedValue({ id: 'test-doc-id' });
        mockCollection = jest.fn().mockReturnValue({ add: mockAdd });
        // Create shared FieldValue and Timestamp objects that will be accessible both ways
        const mockFieldValue = {
            serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP'),
        };
        const mockTimestamp = {
            fromDate: jest.fn((date) => ({ seconds: Math.floor(date.getTime() / 1000) })),
        };
        // Mock firestore instance function
        mockFirestore = jest.fn().mockReturnValue({
            collection: mockCollection,
        });
        // Add static properties to the mock firestore function (for when it's called as a function)
        mockFirestore.FieldValue = mockFieldValue;
        mockFirestore.Timestamp = mockTimestamp;
        // Mock the admin.firestore getter
        firestoreSpy = jest.spyOn(admin, 'firestore').mockImplementation(mockFirestore);
        // Also add the static properties to the spy itself (for direct property access)
        firestoreSpy.FieldValue = mockFieldValue;
        firestoreSpy.Timestamp = mockTimestamp;
        // Setup Monitoring client mocks
        mockListTimeSeries = jest.fn();
        const mockMonitoringClient = {
            listTimeSeries: mockListTimeSeries,
        };
        monitoring_1.MetricServiceClient.mockImplementation(() => mockMonitoringClient);
    });
    afterEach(() => {
        firestoreSpy.mockRestore();
    });
    describe('MetricServiceClient Integration', () => {
        test('should initialize MetricServiceClient', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            expect(monitoring_1.MetricServiceClient).toHaveBeenCalled();
        });
        test('should query execution_count metric for each function', async () => {
            const mockExecutionData = [[
                    {
                        points: [
                            { value: { int64Value: '100' } },
                            { value: { int64Value: '50' } },
                        ],
                    },
                ]];
            mockListTimeSeries.mockResolvedValue(mockExecutionData);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            // Should call listTimeSeries for execution_count, error_count, and execution_times (avg + p95) per function
            expect(mockListTimeSeries).toHaveBeenCalled();
            // Verify execution_count filter was used
            const executionCountCalls = mockListTimeSeries.mock.calls.filter((call) => call[0].filter.includes('execution_count'));
            expect(executionCountCalls.length).toBeGreaterThan(0);
        });
        test('should query error_count metric for each function', async () => {
            const mockErrorData = [[
                    {
                        points: [
                            { value: { int64Value: '5' } },
                        ],
                    },
                ]];
            mockListTimeSeries.mockResolvedValue(mockErrorData);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const errorCountCalls = mockListTimeSeries.mock.calls.filter((call) => call[0].filter.includes('error_count'));
            expect(errorCountCalls.length).toBeGreaterThan(0);
        });
        test('should query execution_times metric for average and p95', async () => {
            const mockTimingData = [[
                    {
                        points: [
                            { value: { doubleValue: 0.5 } }, // 500ms in seconds
                        ],
                    },
                ]];
            mockListTimeSeries.mockResolvedValue(mockTimingData);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const executionTimesCalls = mockListTimeSeries.mock.calls.filter((call) => call[0].filter.includes('execution_times'));
            expect(executionTimesCalls.length).toBeGreaterThan(0);
        });
    });
    describe('Firestore Write Verification', () => {
        test('should write metrics to analytics collection', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            expect(mockCollection).toHaveBeenCalledWith('analytics');
            expect(mockAdd).toHaveBeenCalled();
        });
        test('should verify document structure matches APIMetrics interface', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // Verify required fields
            expect(savedDoc).toHaveProperty('type', 'api_metrics');
            expect(savedDoc).toHaveProperty('period', 'daily');
            expect(savedDoc).toHaveProperty('functions');
            expect(savedDoc).toHaveProperty('overallAvgResponseTime');
            expect(savedDoc).toHaveProperty('overallErrorRate');
            expect(savedDoc).toHaveProperty('totalCalls');
            expect(savedDoc).toHaveProperty('totalErrors');
            expect(savedDoc).toHaveProperty('createdAt');
            expect(savedDoc).toHaveProperty('metrics');
            // Verify nested metrics structure
            expect(savedDoc.metrics).toHaveProperty('functions');
            expect(savedDoc.metrics).toHaveProperty('overallAvgResponseTime');
            expect(savedDoc.metrics).toHaveProperty('overallErrorRate');
            expect(savedDoc.metrics).toHaveProperty('totalCalls');
            expect(savedDoc.metrics).toHaveProperty('totalErrors');
            expect(savedDoc.metrics).toHaveProperty('lastUpdated');
        });
        test('should verify type is api_metrics and period is daily', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            expect(savedDoc.type).toBe('api_metrics');
            expect(savedDoc.period).toBe('daily');
        });
        test('should include all monitored functions in metrics', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // Verify all required functions are present (the list may grow over time)
            const requiredFunctions = new Set([
                'retryProcessVideo',
                'generateSignedUrl',
                'ensureAdminRole',
                'revokeAdminRole',
                'assignAdminRole',
                'processCaptions',
                'processVideoUpload',
                'sendPushNotification',
                'warmCDNCache',
                'aggregateUserAnalytics',
                'aggregateVideoAnalytics',
                'calculateTrendingVideos',
                'monitorStorageUsage',
                'collectCDNMetrics',
                'checkSystemAlerts',
                'systemHealthCheck',
            ]);
            expect(savedDoc.functions.length).toBeGreaterThanOrEqual(requiredFunctions.size);
            const functionNames = new Set(savedDoc.functions.map((f) => f.name));
            requiredFunctions.forEach(name => {
                expect(functionNames.has(name)).toBe(true);
            });
        });
    });
    describe('Error Handling', () => {
        test('should handle MetricServiceClient errors gracefully', async () => {
            mockListTimeSeries.mockRejectedValue(new Error('Monitoring API error'));
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            // Function should not throw - errors are caught per-function and logged
            await expect(collectAPIMetricsHandler()).resolves.toBeUndefined();
            // Should still write metrics (with zero values for failed functions)
            expect(mockCollection).toHaveBeenCalledWith('analytics');
            expect(mockAdd).toHaveBeenCalled();
        });
        test('should continue processing when individual function query fails', async () => {
            // First function fails, rest succeed
            mockListTimeSeries
                .mockRejectedValueOnce(new Error('Function query failed'))
                .mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            // Should still write metrics for other functions
            expect(mockAdd).toHaveBeenCalled();
            const savedDoc = mockAdd.mock.calls[0][0];
            expect(savedDoc.functions.length).toBeGreaterThan(0);
        });
        test('should create admin alert on failure', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            // Make Firestore write fail to trigger main error handler
            mockAdd.mockRejectedValueOnce(new Error('Firestore write failed'));
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await expect(collectAPIMetricsHandler()).rejects.toThrow();
            const alertCalls = mockCollection.mock.calls.filter((call) => call[0] === 'admin_alerts');
            expect(alertCalls.length).toBeGreaterThan(0);
            // Verify alert structure
            const alertDoc = mockAdd.mock.calls.find((call) => call[0]?.type === 'api_metrics_error')?.[0];
            expect(alertDoc).toBeDefined();
            expect(alertDoc.severity).toBe('error');
            expect(alertDoc.acknowledged).toBe(false);
        });
    });
    describe('Edge Cases', () => {
        test('should handle functions with zero invocations', async () => {
            // Return empty results (no data points)
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // All functions should have zero metrics
            savedDoc.functions.forEach((func) => {
                expect(func.totalCalls).toBe(0);
                expect(func.errors).toBe(0);
                expect(func.avgResponseTimeMs).toBe(0);
                expect(func.p95ResponseTimeMs).toBe(0);
                expect(func.errorRate).toBe(0);
            });
        });
        test('should handle missing metric data gracefully', async () => {
            // Return results with missing/null values
            const mockData = [[
                    {
                        points: [
                            { value: {} }, // Empty value object
                            { value: { int64Value: null } }, // Null value
                        ],
                    },
                ]];
            mockListTimeSeries.mockResolvedValue(mockData);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            // Should complete without errors
            expect(mockAdd).toHaveBeenCalled();
        });
        test('should handle division by zero in error rate calculation', async () => {
            // Zero calls, but some errors (edge case)
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // Error rate should be 0 when totalCalls is 0
            expect(savedDoc.overallErrorRate).toBe(0);
        });
        test('should calculate weighted average response time correctly', async () => {
            // Mock different response times for different functions
            const mockExecutionCount = [[{ points: [{ value: { int64Value: '100' } }] }]];
            const mockErrorCount = [[{ points: [{ value: { int64Value: '0' } }] }]];
            const mockAvgTime = [[{ points: [{ value: { doubleValue: 0.2 } }] }]]; // 200ms
            const mockP95Time = [[{ points: [{ value: { doubleValue: 0.5 } }] }]]; // 500ms
            mockListTimeSeries
                .mockResolvedValueOnce(mockExecutionCount) // execution_count
                .mockResolvedValueOnce(mockErrorCount) // error_count
                .mockResolvedValueOnce(mockAvgTime) // avg execution_times
                .mockResolvedValueOnce(mockP95Time) // p95 execution_times
                .mockResolvedValue([[]]); // Other queries
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // Should have calculated weighted average
            expect(savedDoc.overallAvgResponseTime).toBeGreaterThan(0);
            expect(typeof savedDoc.overallAvgResponseTime).toBe('number');
        });
        test('should handle functions with no duration data', async () => {
            const mockExecutionCount = [[{ points: [{ value: { int64Value: '100' } }] }]];
            const mockErrorCount = [[{ points: [{ value: { int64Value: '5' } }] }]];
            const mockNoTime = [[]]; // No timing data
            mockListTimeSeries
                .mockResolvedValueOnce(mockExecutionCount)
                .mockResolvedValueOnce(mockErrorCount)
                .mockResolvedValueOnce(mockNoTime) // avg times
                .mockResolvedValueOnce(mockNoTime) // p95 times
                .mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // Should have calls and errors but zero response times
            expect(savedDoc.totalCalls).toBeGreaterThan(0);
            expect(savedDoc.functions[0].avgResponseTimeMs).toBe(0);
            expect(savedDoc.functions[0].p95ResponseTimeMs).toBe(0);
        });
    });
    describe('Data Structure Validation', () => {
        test('should verify all function metrics have required fields', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            savedDoc.functions.forEach((func) => {
                expect(func).toHaveProperty('name');
                expect(func).toHaveProperty('avgResponseTimeMs');
                expect(func).toHaveProperty('errorRate');
                expect(func).toHaveProperty('totalCalls');
                expect(func).toHaveProperty('p95ResponseTimeMs');
                expect(func).toHaveProperty('errors');
                // Verify types
                expect(typeof func.name).toBe('string');
                expect(typeof func.avgResponseTimeMs).toBe('number');
                expect(typeof func.errorRate).toBe('number');
                expect(typeof func.totalCalls).toBe('number');
                expect(typeof func.p95ResponseTimeMs).toBe('number');
                expect(typeof func.errors).toBe('number');
            });
        });
        test('should verify timestamp conversions', async () => {
            mockListTimeSeries.mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // Verify timestamps are properly formatted
            expect(savedDoc.createdAt).toBe('SERVER_TIMESTAMP');
            expect(savedDoc.metrics.lastUpdated).toHaveProperty('seconds');
            expect(savedDoc.timestamp).toHaveProperty('seconds');
        });
        test('should ensure error rates are between 0 and 1', async () => {
            const mockExecutionCount = [[{ points: [{ value: { int64Value: '1000' } }] }]];
            const mockErrorCount = [[{ points: [{ value: { int64Value: '50' } }] }]];
            mockListTimeSeries
                .mockResolvedValueOnce(mockExecutionCount)
                .mockResolvedValueOnce(mockErrorCount)
                .mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            savedDoc.functions.forEach((func) => {
                expect(func.errorRate).toBeGreaterThanOrEqual(0);
                expect(func.errorRate).toBeLessThanOrEqual(1);
            });
            expect(savedDoc.overallErrorRate).toBeGreaterThanOrEqual(0);
            expect(savedDoc.overallErrorRate).toBeLessThanOrEqual(1);
        });
        test('should round floating point values appropriately', async () => {
            const mockAvgTime = [[{ points: [{ value: { doubleValue: 0.123456789 } }] }]];
            mockListTimeSeries
                .mockResolvedValueOnce([[{ points: [{ value: { int64Value: '100' } }] }]]) // execution
                .mockResolvedValueOnce([[{ points: [{ value: { int64Value: '7' } }] }]]) // errors
                .mockResolvedValueOnce(mockAvgTime) // avg time
                .mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // Response times should be rounded to 2 decimals
            const funcWithTime = savedDoc.functions.find((f) => f.avgResponseTimeMs > 0);
            if (funcWithTime) {
                const decimalPlaces = funcWithTime.avgResponseTimeMs.toString().split('.')[1]?.length || 0;
                expect(decimalPlaces).toBeLessThanOrEqual(2);
            }
            // Error rates should be rounded to 3 decimals
            const funcWithErrors = savedDoc.functions.find((f) => f.errorRate > 0);
            if (funcWithErrors) {
                const decimalPlaces = funcWithErrors.errorRate.toString().split('.')[1]?.length || 0;
                expect(decimalPlaces).toBeLessThanOrEqual(3);
            }
        });
    });
    describe('Integration Scenarios', () => {
        test('should handle realistic metric data', async () => {
            // Simulate realistic Cloud Monitoring data
            const mockRealisticData = {
                execution: [[{ points: [
                                { value: { int64Value: '1500' } },
                                { value: { int64Value: '1200' } },
                            ] }]],
                errors: [[{ points: [
                                { value: { int64Value: '15' } },
                                { value: { int64Value: '8' } },
                            ] }]],
                avgTime: [[{ points: [
                                { value: { doubleValue: 0.25 } }, // 250ms
                                { value: { doubleValue: 0.30 } }, // 300ms
                            ] }]],
                p95Time: [[{ points: [
                                { value: { doubleValue: 0.85 } }, // 850ms
                                { value: { doubleValue: 0.92 } }, // 920ms
                            ] }]],
            };
            mockListTimeSeries
                .mockResolvedValueOnce(mockRealisticData.execution)
                .mockResolvedValueOnce(mockRealisticData.errors)
                .mockResolvedValueOnce(mockRealisticData.avgTime)
                .mockResolvedValueOnce(mockRealisticData.p95Time)
                .mockResolvedValue([[]]);
            const { collectAPIMetricsHandler } = require('../../analytics/apiMetrics');
            await collectAPIMetricsHandler();
            const savedDoc = mockAdd.mock.calls[0][0];
            // First function should have realistic values
            const firstFunc = savedDoc.functions[0];
            expect(firstFunc.totalCalls).toBe(2700); // 1500 + 1200
            expect(firstFunc.errors).toBe(23); // 15 + 8
            expect(firstFunc.errorRate).toBeCloseTo(23 / 2700, 3);
            expect(firstFunc.avgResponseTimeMs).toBeGreaterThan(0);
            expect(firstFunc.p95ResponseTimeMs).toBeGreaterThan(0);
        });
    });
});
//# sourceMappingURL=apiMetrics.test.js.map