import { NextResponse } from 'next/server';

export async function GET() {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;

  if (!cloudName || !apiKey || !apiSecret) {
    return NextResponse.json({ error: 'Cloudinary credentials missing' }, { status: 400 });
  }

  try {
    const auth = Buffer.from(`${apiKey}:${apiSecret}`).toString('base64');
    // List recent video resources to approximate active/failed jobs.
    const res = await fetch(
      `https://api.cloudinary.com/v1_1/${cloudName}/resources/video?max_results=50`,
      {
        headers: {
          Authorization: `Basic ${auth}`,
        },
        cache: 'no-store',
      }
    );

    if (!res.ok) {
      const text = await res.text();
      return NextResponse.json({ error: 'Failed to fetch Cloudinary jobs', detail: text }, { status: 500 });
    }

    const data: any = await res.json();
    const resources = Array.isArray(data?.resources) ? data.resources : [];
    const failedJobs = resources.filter((r: any) => r?.status === 'error').length;
    const activeJobs = resources.filter((r: any) => r?.status === 'uploading' || r?.status === 'processing').length;

    return NextResponse.json({
      activeJobs,
      failedJobs,
      lastChecked: new Date().toISOString(),
    });
  } catch (error: any) {
    return NextResponse.json({ error: error?.message || 'Unknown error' }, { status: 500 });
  }
}
