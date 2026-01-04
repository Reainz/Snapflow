import { NextResponse } from 'next/server';

/**
 * Lightweight Cloudinary usage proxy (server-side) to avoid exposing credentials in the client.
 * Requires env: CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET.
 */
export async function GET() {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;

  if (!cloudName || !apiKey || !apiSecret) {
    return NextResponse.json({ error: 'Cloudinary credentials missing' }, { status: 400 });
  }

  try {
    const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
    const res = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/usage`, {
      headers: {
        Authorization: `Basic ${auth}`,
      },
      cache: 'no-store',
    });

    if (!res.ok) {
      const text = await res.text();
      return NextResponse.json({ error: 'Failed to fetch Cloudinary usage', detail: text }, { status: 500 });
    }

    const usage: any = await res.json();

    const numberOrNull = (v: any): number | null => {
      if (typeof v === 'number') return v;
      if (typeof v === 'string') {
        const n = Number(v);
        return Number.isNaN(n) ? null : n;
      }
      return null;
    };

    // Direct access to API response fields
    const bandwidthSection = usage?.bandwidth ?? {};
    const storageSection = usage?.storage ?? {};

    const bandwidthBytes = numberOrNull(bandwidthSection.usage) ?? 0;
    const storageBytes = numberOrNull(storageSection.usage) ?? 0;

    const payload = {
      bandwidthBytes,
      bandwidthGB: bandwidthBytes / (1024 ** 3),
      bandwidthLimitBytes: numberOrNull(bandwidthSection.limit),
      bandwidthLimitGB: bandwidthSection.limit ? bandwidthSection.limit / (1024 ** 3) : null,
      storageBytes,
      storageGB: storageBytes / (1024 ** 3),
      storageLimitBytes: numberOrNull(storageSection.limit),
      storageLimitGB: storageSection.limit ? storageSection.limit / (1024 ** 3) : null,
      requests: numberOrNull(usage?.requests),
      resourceCount: numberOrNull(usage?.resources),
      lastUpdated: usage?.last_updated || null,
    };

    return NextResponse.json(payload);
  } catch (error: any) {
    return NextResponse.json({ error: error?.message || 'Unknown error' }, { status: 500 });
  }
}
