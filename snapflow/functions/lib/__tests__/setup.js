"use strict";
/**
 * Jest Test Setup
 * Sets up environment variables and mocks for testing
 */
// Set up test environment variables
process.env.CLOUDINARY_CLOUD_NAME = 'test-cloud-name';
process.env.CLOUDINARY_API_KEY = 'test-api-key';
process.env.CLOUDINARY_API_SECRET = 'test-api-secret';
// Mock console to reduce noise in tests (optional)
global.console = {
    ...console,
    // Uncomment to suppress logs during tests
    // log: jest.fn(),
    // debug: jest.fn(),
    // info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
};
//# sourceMappingURL=setup.js.map