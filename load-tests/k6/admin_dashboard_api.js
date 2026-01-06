import http from 'k6/http';
import { check, group, sleep, fail } from 'k6';

const BASE_URL = (__ENV.BASE_URL || 'http://localhost:3000').replace(/\/+$/, '');

function numEnv(key, fallback) {
  const raw = __ENV[key];
  if (!raw) return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export const options = (() => {
  const testType = (__ENV.TEST_TYPE || 'smoke').toLowerCase();

  if (testType === 'stress') {
    return {
      stages: [
        { duration: '30s', target: 5 },
        { duration: '1m', target: 20 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 0 },
      ],
      thresholds: {
        http_req_failed: ['rate<0.02'],
        http_req_duration: ['p(95)<2000'],
      },
    };
  }

  return {
    vus: numEnv('VUS', 5),
    duration: __ENV.DURATION || '30s',
    thresholds: {
      http_req_failed: ['rate<0.01'],
      http_req_duration: ['p(95)<1500'],
    },
  };
})();

function signInWithPassword() {
  const apiKey = __ENV.FIREBASE_API_KEY;
  const email = __ENV.E2E_EMAIL;
  const password = __ENV.E2E_PASSWORD;

  if (!apiKey || !email || !password) {
    fail(
      'Missing auth. Provide ID_TOKEN or (FIREBASE_API_KEY + E2E_EMAIL + E2E_PASSWORD).'
    );
  }

  const res = http.post(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(
      apiKey
    )}`,
    JSON.stringify({ email, password, returnSecureToken: true }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  if (!check(res, { 'auth: 200': (r) => r.status === 200 })) {
    fail(`Auth failed: HTTP ${res.status} ${res.body?.slice?.(0, 200) ?? ''}`);
  }

  const data = res.json();
  const token = data?.idToken;
  if (!token) fail('Auth response missing idToken');
  return token;
}

export function setup() {
  const token = __ENV.ID_TOKEN || signInWithPassword();
  return { token };
}

export default function (data) {
  const headers = {
    Authorization: `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  };

  group('stats', () => {
    const res = http.get(`${BASE_URL}/api/stats`, { headers });
    check(res, {
      'stats: 200': (r) => r.status === 200,
      'stats: json': (r) => {
        try {
          const j = r.json();
          return typeof j?.totalUsers === 'number' && typeof j?.totalVideos === 'number';
        } catch {
          return false;
        }
      },
    });
  });

  group('analytics', () => {
    const types = ['system_health', 'cdn_metrics', 'api_metrics'];
    for (const type of types) {
      const res = http.get(`${BASE_URL}/api/analytics?type=${encodeURIComponent(type)}`, { headers });
      check(res, {
        [`analytics:${type}: 200`]: (r) => r.status === 200,
      });
    }
  });

  sleep(1);
}

