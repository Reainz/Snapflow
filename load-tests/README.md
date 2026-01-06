## Load/Stress Tests (k6)

This folder contains simple, thesis-friendly load/stress tests written as code using `k6`.

### What it tests
- `snapflow-admin` authenticated API routes:
  - `GET /api/stats`
  - `GET /api/analytics?type=system_health`
  - `GET /api/analytics?type=cdn_metrics`
  - `GET /api/analytics?type=api_metrics`

### Prerequisites
- Install k6: https://k6.io/docs/get-started/installation/
- Use a **staging** deployment of the admin dashboard (recommended).
- For auto-scaling benchmarks: Install Node.js dependencies: `cd load-tests && npm install`

### Auth options
You must provide an auth token for the admin dashboard API routes.

1) **Preferred (no credentials in scripts)**: provide a Firebase ID token directly
- Set `ID_TOKEN` env var to an admin user's Firebase ID token.

2) **Automated**: have k6 mint a token via Firebase Auth REST API
- Set `FIREBASE_API_KEY`, `E2E_EMAIL`, `E2E_PASSWORD`.
- This signs in with email/password and fetches an ID token in `setup()`.

### Run (smoke)
```bash
set BASE_URL=https://<your-staging-admin-domain>
set ID_TOKEN=<paste-id-token>
k6 run load-tests/k6/admin_dashboard_api.js
```

### Run (stress)
```bash
set BASE_URL=https://<your-staging-admin-domain>
set ID_TOKEN=<paste-id-token>
set TEST_TYPE=stress
k6 run load-tests/k6/admin_dashboard_api.js
```

### Tuning
- `VUS` (default: 5)
- `DURATION` (default: 30s)
- `TEST_TYPE=stress` enables ramp stages

---

## Auto-Scaling Benchmark Tests

Automated benchmark tests that combine k6 load testing with Google Cloud Monitoring API metrics to analyze auto-scaling behavior.

### What it tests
- **Load Generation**: Gradual ramp-up from 5 to 100 virtual users over ~20 minutes
- **Scaling Metrics**: Cloud Functions execution count, concurrent executions, response times
- **Database Scaling**: Firestore read/write operations
- **Infrastructure Scaling**: Cloud Run instance count (if applicable)

### Prerequisites
1. Install k6: https://k6.io/docs/get-started/installation/
2. Install Node.js dependencies:
   ```bash
   cd load-tests
   npm install
   ```
3. Authenticate with Google Cloud (for metrics API):
   ```bash
   gcloud auth application-default login
   # OR set GOOGLE_APPLICATION_CREDENTIALS to service account JSON
   ```
4. Ensure admin dashboard is running (local or staging)

### Quick Start (Automated)

Run the complete benchmark test (k6 + metrics + report):

```bash
cd load-tests

# Set environment variables
$env:BASE_URL="http://localhost:3001"  # or your staging URL
$env:FIREBASE_API_KEY="your-api-key"
$env:E2E_EMAIL="demo1@snapflow.test"
$env:E2E_PASSWORD="Demo123!"
$env:FIREBASE_PROJECT_ID="snapflow-4577d"  # optional, defaults to snapflow-4577d

# Run benchmark
npm run benchmark
```

This will:
1. Run k6 load test with gradual ramp-up (~20 minutes)
2. Fetch GCP metrics from Google Cloud Monitoring API
3. Generate an HTML report with scaling analysis

### Manual Steps

#### Step 1: Run k6 Load Test
```bash
cd load-tests
$env:BASE_URL="http://localhost:3001"
$env:FIREBASE_API_KEY="your-api-key"
$env:E2E_EMAIL="demo1@snapflow.test"
$env:E2E_PASSWORD="Demo123!"
k6 run k6/autoscaling_benchmark.js --out json=k6_results.json
```

#### Step 2: Fetch GCP Metrics
```bash
# Note the test start/end times, then:
node scripts/fetch_gcp_metrics.mjs \
  --start-time="2026-01-05T12:00:00Z" \
  --end-time="2026-01-05T12:20:00Z" \
  > gcp_metrics.json
```

#### Step 3: Generate Report
```bash
node scripts/generate_autoscaling_report.mjs \
  --k6-results=k6_results.json \
  --gcp-metrics=gcp_metrics.json \
  --output=autoscaling_report.html
```

### Understanding the Results

The generated HTML report includes:

1. **Test Overview**: Duration, peak VUs, total requests, error rate
2. **Performance Metrics**: Average, P95, P99 response times
3. **Auto-Scaling Analysis**:
   - Cloud Functions: Execution count, concurrent executions, errors per function
   - Firestore: Document reads/writes
   - Cloud Run: Instance count (if applicable)
4. **Scaling Observations**: Key findings and recommendations

### Key Metrics Tracked

- **Cloud Functions**:
  - `execution_count`: Total function invocations
  - `execution_times`: Average execution duration
  - `error_count`: Failed executions
  - `concurrent_executions`: Peak concurrent instances

- **Firestore**:
  - `document/read_count`: Total document reads
  - `document/write_count`: Total document writes

- **Cloud Run** (if admin dashboard is deployed):
  - `request_count`: Total HTTP requests
  - `container/instance_count`: Number of scaled instances

### Notes

- **Test Duration**: ~20 minutes (gradual ramp-up to observe scaling)
- **Metric Propagation**: GCP metrics may take 1-2 minutes to appear after test completion
- **Staging Environment**: Recommended for realistic scaling behavior
- **Auto-Scaling**: Firebase Cloud Functions auto-scale automatically; this test observes and measures the behavior

### Troubleshooting

**"Permission denied" when fetching GCP metrics:**
- Ensure you're authenticated: `gcloud auth application-default login`
- Or set `GOOGLE_APPLICATION_CREDENTIALS` to a service account JSON file

**"No metrics found":**
- Wait 2-3 minutes after test completion for metrics to propagate
- Verify the time range includes the test period
- Check that functions were actually invoked during the test

**k6 test fails:**
- Ensure admin dashboard is running and accessible
- Verify authentication credentials are correct
- Check that demo account has admin privileges
