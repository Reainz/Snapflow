import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';

/**
 * Temporary callable function to inspect FIREBASE_CONFIG at runtime.
 * Returns and logs the parsed config so you can confirm storageBucket.
 */
export const debugRuntimeConfig = onCall(async () => {
  const raw = process.env.FIREBASE_CONFIG || '{}';

  logger.info('FIREBASE_CONFIG_RAW', { raw });

  let parsed: any = {};
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    logger.error('Failed to parse FIREBASE_CONFIG', error as any);
  }

  const storageBucket = parsed.storageBucket ?? null;
  const projectId = parsed.projectId ?? null;

  logger.info('FIREBASE_CONFIG_PARSED', {
    storageBucket,
    projectId,
  });

  return {
    storageBucket,
    projectId,
  };
});

