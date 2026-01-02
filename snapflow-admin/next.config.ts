import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      // Cloudinary CDN (Flow B processed videos/thumbnails)
      { protocol: "https", hostname: "res.cloudinary.com" },
      // Fallback for other static assets if needed
      { protocol: "https", hostname: "images.unsplash.com" },
    ],
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "no-referrer" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
          { key: "Content-Security-Policy", value: "default-src 'self'; img-src 'self' https://res.cloudinary.com https://images.unsplash.com https://lh3.googleusercontent.com data:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://apis.google.com; style-src 'self' 'unsafe-inline'; font-src 'self' data:; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com https://*.cloudfunctions.net https://api.cloudinary.com https://res.cloudinary.com; frame-ancestors 'none'; object-src 'none'; base-uri 'self'; form-action 'self';" },
        ],
      },
    ];
  },
  // Note: firebase-admin cannot be used in middleware (Edge Runtime)
  // Middleware needs to be refactored to use API routes for auth verification
};

export default nextConfig;
