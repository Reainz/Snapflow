/**
 * Integration tests for cleanupRawVideos scheduled function.
 * Ensures raw-videos/ files are deleted when failed, orphaned, or stuck processing.
 */

// Mocks
const analyticsWrites: any[] = [];
let videoDocs: Record<string, any> = {};
let storageFiles: any[] = [];

const mockAnalyticsAdd = jest.fn(async (payload: any) => {
  analyticsWrites.push(payload);
});

const makeTimestamp = (msAgo: number) => ({
  toMillis: () => Date.now() - msAgo,
});

jest.mock('firebase-admin', () => {
  const buildQuery = (filters: any[] = []) => ({
    where: (field: string, op: string, value: any) =>
      buildQuery([...filters, { type: 'where', field, op, value }]),
    orderBy: (field: string) => buildQuery([...filters, { type: 'orderBy', field }]),
    limit: (count: number) => buildQuery([...filters, { type: 'limit', value: count }]),
    startAfter: (_doc: any) => buildQuery(filters),
    get: async () => {
      let entries = Object.entries(videoDocs).map(([id, data]) => ({ id, data }));

      for (const f of filters) {
        if (f.type === 'where' && f.op === '==') {
          entries = entries.filter((e) => e.data[f.field] === f.value);
        } else if (f.type === 'where' && f.op === '<=') {
          entries = entries.filter((e) => {
            const val = e.data[f.field];
            return val && typeof val.toMillis === 'function' && val.toMillis() <= f.value.toMillis();
          });
        }
      }

      const limitFilter = filters.find((f) => f.type === 'limit');
      if (limitFilter) {
        entries = entries.slice(0, limitFilter.value);
      }

      const docs = entries.map((e) => ({
        id: e.id,
        data: () => e.data,
      }));

      return {
        empty: docs.length === 0,
        size: docs.length,
        docs,
      };
    },
  });

  const firestoreFn: any = jest.fn(() => ({
    collection: (name: string) => {
      if (name === 'videos') {
        const queryApi = buildQuery();
        return {
          doc: (id: string) => ({
            get: async () => {
              const data = videoDocs[id];
              return {
                exists: !!data,
                data: () => data,
              };
            },
          }),
          where: queryApi.where,
          orderBy: queryApi.orderBy,
          limit: queryApi.limit,
          startAfter: queryApi.startAfter,
          get: queryApi.get,
        };
      }
      if (name === 'analytics') {
        return {
          add: mockAnalyticsAdd,
        };
      }
      return {
        doc: jest.fn(() => ({
          get: jest.fn(),
        })),
      };
    },
  }));

  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => ({ serverTimestamp: true })),
  };
  firestoreFn.Timestamp = {
    fromMillis: (ms: number) => ({
      toMillis: () => ms,
    }),
  };

  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
    storage: jest.fn(() => ({
      bucket: jest.fn(() => ({
        getFiles: jest.fn(async () => [storageFiles]),
      })),
    })),
    firestoreNamespace: {},
    firestoreService: {},
    FieldValue: firestoreFn.FieldValue,
    Timestamp: firestoreFn.Timestamp,
  };
});

// Silence logger usage
jest.mock('firebase-functions', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

import { runCleanupRawVideos } from '../../storage/cleanupRawVideos';

describe('cleanupRawVideos', () => {
  beforeEach(() => {
    analyticsWrites.length = 0;
    mockAnalyticsAdd.mockClear();
    videoDocs = {};
    storageFiles = [];
  });

  const buildFile = (name: string, size = 1000) => ({
    name,
    metadata: { size: String(size) },
    delete: jest.fn(async () => Promise.resolve()),
  });

  test('deletes failed videos older than 3 days', async () => {
    videoDocs = {
      oldfail: { status: 'failed', lastErrorAt: makeTimestamp(4 * 24 * 60 * 60 * 1000) },
    };
    const file = buildFile('raw-videos/u1/oldfail.mp4', 2048);
    storageFiles = [file];

    await runCleanupRawVideos();

    expect(file.delete).toHaveBeenCalledTimes(1);
    expect(analyticsWrites[0].failedVideosDeleted).toBe(1);
    expect(analyticsWrites[0].totalSizeFreedBytes).toBe(2048);
  });

  test('deletes orphaned files with no Firestore document', async () => {
    const file = buildFile('raw-videos/u2/orphan.mp4');
    storageFiles = [file];

    await runCleanupRawVideos();

    expect(file.delete).toHaveBeenCalledTimes(1);
    expect(analyticsWrites[0].orphanedFilesDeleted).toBe(1);
  });

  test('deletes processing videos stuck longer than 7 days', async () => {
    videoDocs = {
      stuck: { status: 'processing', createdAt: makeTimestamp(8 * 24 * 60 * 60 * 1000) },
    };
    const file = buildFile('raw-videos/u3/stuck.mp4');
    storageFiles = [file];

    await runCleanupRawVideos();

    expect(file.delete).toHaveBeenCalledTimes(1);
    expect(analyticsWrites[0].stuckProcessingDeleted).toBe(1);
  });

  test('preserves recent failed videos newer than 3 days', async () => {
    videoDocs = {
      recentfail: { status: 'failed', lastErrorAt: makeTimestamp(24 * 60 * 60 * 1000) },
    };
    const file = buildFile('raw-videos/u4/recentfail.mp4');
    storageFiles = [file];

    await runCleanupRawVideos();

    expect(file.delete).not.toHaveBeenCalled();
    expect(analyticsWrites[0].failedVideosDeleted).toBe(0);
  });

  test('never deletes ready videos', async () => {
    videoDocs = {
      readyvid: { status: 'ready', createdAt: makeTimestamp(10 * 24 * 60 * 60 * 1000) },
    };
    const file = buildFile('raw-videos/u5/readyvid.mp4');
    storageFiles = [file];

    await runCleanupRawVideos();

    expect(file.delete).not.toHaveBeenCalled();
    expect(analyticsWrites[0].failedVideosDeleted).toBe(0);
    expect(analyticsWrites[0].stuckProcessingDeleted).toBe(0);
    expect(analyticsWrites[0].orphanedFilesDeleted).toBe(0);
  });
});
