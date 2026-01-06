import http from 'k6/http';
import { check, group, sleep, fail } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics for auto-scaling analysis
export const scalingMetrics = {
  requestRate: new Rate('scaling_request_rate'),
  responseTime: new Trend('scaling_response_time'),
  errorRate: new Rate('scaling_error_rate'),
  concurrentRequests: new Counter('scaling_concurrent_requests'),
};

const BASE_URL = (__ENV.BASE_URL || 'http://localhost:3001').replace(/\/+$/, '');

function numEnv(key, fallback) {
  const raw = __ENV[key];
  if (!raw) return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * Auto-scaling benchmark test configuration
 * Gradually increases load to observe scaling behavior
 */
export const options = {
  stages: [
    // Warm-up phase: low load
    { duration: '1m', target: 5 },
    // Ramp-up phase 1: moderate load
    { duration: '2m', target: 20 },
    // Ramp-up phase 2: high load
    { duration: '3m', target: 50 },
    // Sustained load: observe scaling
    { duration: '5m', target: 50 },
    // Peak load: stress test
    { duration: '2m', target: 100 },
    // Sustained peak: observe max scaling
    { duration: '3m', target: 100 },
    // Cool-down phase
    { duration: '2m', target: 20 },
    { duration: '1m', target: 5 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'], // Allow up to 5% errors during scaling
    http_req_duration: ['p(95)<5000'], // More lenient during scaling tests
    'scaling_error_rate': ['rate<0.05'],
  },
};

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
  return { 
    token,
    startTime: new Date().toISOString(),
  };
}

export default function (data) {
  const headers = {
    Authorization: `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  };

  // Track concurrent requests
  scalingMetrics.concurrentRequests.add(1);

  const requestStart = Date.now();

  group('stats', () => {
    const res = http.get(`${BASE_URL}/api/stats`, { headers });
    const duration = Date.now() - requestStart;
    
    scalingMetrics.responseTime.add(duration);
    scalingMetrics.requestRate.add(1);
    
    const success = check(res, {
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
    
    scalingMetrics.errorRate.add(!success);
  });

  group('analytics', () => {
    const types = ['system_health', 'cdn_metrics', 'api_metrics'];
    for (const type of types) {
      const res = http.get(
        `${BASE_URL}/api/analytics?type=${encodeURIComponent(type)}`,
        { headers }
      );
      check(res, {
        [`analytics:${type}: 200`]: (r) => r.status === 200,
      });
    }
  });

  scalingMetrics.concurrentRequests.add(-1);
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify({
      testType: 'autoscaling_benchmark',
      timestamp: new Date().toISOString(),
      summary: {
        totalRequests: data.metrics.http_reqs?.values?.count || 0,
        totalErrors: data.metrics.http_req_failed?.values?.rate || 0,
        avgResponseTime: data.metrics.http_req_duration?.values?.avg || 0,
        p95ResponseTime: data.metrics.http_req_duration?.values?.['p(95)'] || 0,
        p99ResponseTime: data.metrics.http_req_duration?.values?.['p(99)'] || 0,
        maxVUs: data.metrics.vus_max?.values?.max || 0,
        testDuration: data.state?.testRunDurationMs || 0,
      },
    }, null, 2),
  };
}
