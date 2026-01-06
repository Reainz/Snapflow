#!/usr/bin/env node
// Automated auto-scaling benchmark test runner
// Orchestrates k6 load test + GCP metrics collection + report generation
// Usage: node run_autoscaling_benchmark.mjs

import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = join(__dirname, '../..');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || 'snapflow-4577d';
const BASE_URL = process.env.BASE_URL || 'http://localhost:3001';
const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY;
const E2E_EMAIL = process.env.E2E_EMAIL || 'demo1@snapflow.test';
const E2E_PASSWORD = process.env.E2E_PASSWORD || 'Demo123!';

/**
 * Run k6 load test and capture results
 */
function runK6Test() {
  return new Promise((resolve, reject) => {
    console.log('🚀 Starting k6 auto-scaling benchmark test...');
    console.log(`   Target: ${BASE_URL}`);
    console.log(`   Duration: ~20 minutes (gradual ramp-up)`);

    const k6Script = join(__dirname, '../k6/autoscaling_benchmark.js');
    const env = {
      ...process.env,
      BASE_URL,
      FIREBASE_API_KEY,
      E2E_EMAIL,
      E2E_PASSWORD,
    };

    const k6 = spawn('k6', ['run', k6Script], {
      env,
      cwd: PROJECT_ROOT,
      stdio: ['inherit', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    k6.stdout.on('data', (data) => {
      const text = data.toString();
      stdout += text;
      process.stdout.write(text);
    });

    k6.stderr.on('data', (data) => {
      const text = data.toString();
      stderr += text;
      process.stderr.write(text);
    });

    k6.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`k6 test failed with code ${code}\n${stderr}`));
        return;
      }

      // Parse k6 JSON output from stdout
      try {
        const jsonMatch = stdout.match(/\{[\s\S]*"testType":\s*"autoscaling_benchmark"[\s\S]*\}/);
        if (jsonMatch) {
          const k6Results = JSON.parse(jsonMatch[0]);
          resolve(k6Results);
        } else {
          // Fallback: create summary from stdout
          resolve({
            summary: {
              totalRequests: 0,
              totalErrors: 0,
              avgResponseTime: 0,
              p95ResponseTime: 0,
              p99ResponseTime: 0,
              maxVUs: 0,
              testDuration: 0,
            },
          });
        }
      } catch (error) {
        console.warn('Could not parse k6 JSON output, using fallback');
        resolve({
          summary: {
            totalRequests: 0,
            totalErrors: 0,
            avgResponseTime: 0,
            p95ResponseTime: 0,
            p99ResponseTime: 0,
            maxVUs: 0,
            testDuration: 0,
          },
        });
      }
    });

    k6.on('error', (error) => {
      reject(new Error(`Failed to start k6: ${error.message}`));
    });
  });
}

/**
 * Fetch GCP metrics for the test time range
 */
async function fetchGCPMetrics(startTime, endTime) {
  console.log('\n📊 Fetching GCP metrics from Google Cloud Monitoring API...');
  console.log(`   Time range: ${startTime.toISOString()} to ${endTime.toISOString()}`);

  return new Promise((resolve, reject) => {
    const fetchScript = join(__dirname, 'fetch_gcp_metrics.mjs');
    const env = {
      ...process.env,
      FIREBASE_PROJECT_ID: PROJECT_ID,
      GCLOUD_PROJECT: PROJECT_ID,
    };

    const node = spawn('node', [
      fetchScript,
      '--start-time',
      startTime.toISOString(),
      '--end-time',
      endTime.toISOString(),
    ], {
      env,
      cwd: PROJECT_ROOT,
      stdio: ['inherit', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    node.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    node.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    node.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`GCP metrics fetch failed with code ${code}\n${stderr}`));
        return;
      }

      try {
        // Parse JSON from stdout (last JSON object)
        const jsonMatch = stdout.match(/\{[\s\S]*"projectId"[\s\S]*\}/);
        if (jsonMatch) {
          const gcpMetrics = JSON.parse(jsonMatch[0]);
          resolve(gcpMetrics);
        } else {
          reject(new Error('Could not parse GCP metrics JSON output'));
        }
      } catch (error) {
        reject(new Error(`Failed to parse GCP metrics: ${error.message}`));
      }
    });

    node.on('error', (error) => {
      reject(new Error(`Failed to start metrics fetch: ${error.message}`));
    });
  });
}

/**
 * Generate HTML report
 */
function generateReport(k6Results, gcpMetrics) {
  console.log('\n📝 Generating auto-scaling benchmark report...');

  return new Promise((resolve, reject) => {
    const k6ResultsFile = join(PROJECT_ROOT, 'load-tests', 'k6_results.json');
    const gcpMetricsFile = join(PROJECT_ROOT, 'load-tests', 'gcp_metrics.json');
    const reportFile = join(PROJECT_ROOT, 'load-tests', 'autoscaling_report.html');

    // Save intermediate files
    writeFileSync(k6ResultsFile, JSON.stringify(k6Results, null, 2), 'utf8');
    writeFileSync(gcpMetricsFile, JSON.stringify(gcpMetrics, null, 2), 'utf8');

    const reportScript = join(__dirname, 'generate_autoscaling_report.mjs');
    const node = spawn('node', [
      reportScript,
      '--k6-results',
      k6ResultsFile,
      '--gcp-metrics',
      gcpMetricsFile,
      '--output',
      reportFile,
    ], {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
    });

    node.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Report generation failed with code ${code}`));
        return;
      }
      resolve(reportFile);
    });

    node.on('error', (error) => {
      reject(new Error(`Failed to generate report: ${error.message}`));
    });
  });
}

/**
 * Main execution
 */
async function main() {
  console.log('='.repeat(60));
  console.log('Auto-Scaling Benchmark Test - Snapflow');
  console.log('='.repeat(60));
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test Duration: ~20 minutes\n`);

  if (!FIREBASE_API_KEY) {
    console.error('❌ Missing FIREBASE_API_KEY environment variable');
    console.error('   Set it to your Firebase Web API key');
    process.exit(1);
  }

  const testStartTime = new Date();
  console.log(`Test started at: ${testStartTime.toISOString()}\n`);

  try {
    // Step 1: Run k6 load test
    const k6Results = await runK6Test();
    const testEndTime = new Date();

    console.log('\n✅ k6 load test completed');
    console.log(`   Duration: ${Math.floor((testEndTime - testStartTime) / 1000 / 60)} minutes`);

    // Step 2: Fetch GCP metrics (add 2-minute buffer for metric propagation)
    const metricsStartTime = new Date(testStartTime.getTime() - 2 * 60 * 1000);
    const metricsEndTime = new Date(testEndTime.getTime() + 2 * 60 * 1000);

    const gcpMetrics = await fetchGCPMetrics(metricsStartTime, metricsEndTime);
    console.log('✅ GCP metrics collected');

    // Step 3: Generate report
    const reportFile = await generateReport(k6Results, gcpMetrics);
    console.log('\n✅ Auto-scaling benchmark report generated!');
    console.log(`\n📄 Report: ${reportFile}`);
    console.log(`   Open in browser to view the results\n`);

    console.log('='.repeat(60));
    console.log('Summary:');
    console.log(`  Total Requests: ${k6Results.summary?.totalRequests || 0}`);
    console.log(`  Error Rate: ${((k6Results.summary?.totalErrors || 0) / (k6Results.summary?.totalRequests || 1) * 100).toFixed(2)}%`);
    console.log(`  P95 Response Time: ${((k6Results.summary?.p95ResponseTime || 0) / 1000).toFixed(2)}s`);
    console.log(`  Peak VUs: ${k6Results.summary?.maxVUs || 0}`);
    console.log('='.repeat(60));

  } catch (error) {
    console.error('\n❌ Benchmark test failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
