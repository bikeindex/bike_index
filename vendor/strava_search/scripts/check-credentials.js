#!/usr/bin/env node

/**
 * Pre-commit hook script to check for potential credential leaks.
 * Scans staged files for patterns that look like API keys, tokens, or secrets.
 */

import { execSync } from 'child_process';
import { readFileSync } from 'fs';

// Patterns that indicate potential credential leaks
const CREDENTIAL_PATTERNS = [
  // Strava tokens (typically 40 char hex or alphanumeric)
  { pattern: /["']?access_token["']?\s*[:=]\s*["'][a-f0-9]{40}["']/gi, name: 'Strava access token' },
  { pattern: /["']?refresh_token["']?\s*[:=]\s*["'][a-f0-9]{40}["']/gi, name: 'Strava refresh token' },

  // Generic API keys and secrets (not redacted placeholders)
  { pattern: /["']?client_secret["']?\s*[:=]\s*["'][a-f0-9]{30,}["']/gi, name: 'Client secret' },
  { pattern: /["']?api_key["']?\s*[:=]\s*["'][a-zA-Z0-9_-]{20,}["']/gi, name: 'API key' },

  // Bearer tokens in code (not in test fixtures with [REDACTED])
  { pattern: /Bearer\s+[a-f0-9]{40}/gi, name: 'Bearer token' },

  // OAuth codes
  { pattern: /["']?code["']?\s*[:=]\s*["'][a-f0-9]{30,}["']/gi, name: 'OAuth code' },

  // Private keys
  { pattern: /-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/gi, name: 'Private key' },

  // AWS credentials
  { pattern: /AKIA[0-9A-Z]{16}/gi, name: 'AWS access key' },

  // Generic secret patterns (but not placeholder text)
  { pattern: /["']sk_live_[a-zA-Z0-9]{24,}["']/gi, name: 'Stripe secret key' },
];

// Files/patterns to ignore
const IGNORE_PATTERNS = [
  /node_modules/,
  /\.git\//,
  /dist\//,
  /storybook-static\//,
  /\.test\.(ts|tsx|js|jsx)$/,  // Test files may have mock credentials
  /cassettes\/.*\.json$/,       // VCR cassettes should have redacted credentials
  /check-credentials\.js$/,     // This file itself
];

// Allowed patterns (redacted placeholders)
const ALLOWED_PATTERNS = [
  /\[REDACTED\]/,
  /\[ATHLETE_ID\]/,
  /YOUR_.*_HERE/i,
  /example\.com/,
  /<your-.*>/i,
];

function shouldIgnoreFile(filepath) {
  return IGNORE_PATTERNS.some(pattern => pattern.test(filepath));
}

function hasAllowedPattern(line) {
  return ALLOWED_PATTERNS.some(pattern => pattern.test(line));
}

function checkFileForCredentials(filepath) {
  if (shouldIgnoreFile(filepath)) {
    return [];
  }

  let content;
  try {
    content = readFileSync(filepath, 'utf-8');
  } catch (err) {
    // File might be deleted or inaccessible
    return [];
  }

  const issues = [];
  const lines = content.split('\n');

  lines.forEach((line, index) => {
    // Skip lines with allowed placeholder patterns
    if (hasAllowedPattern(line)) {
      return;
    }

    CREDENTIAL_PATTERNS.forEach(({ pattern, name }) => {
      if (pattern.test(line)) {
        issues.push({
          file: filepath,
          line: index + 1,
          type: name,
          content: line.trim().substring(0, 80) + (line.length > 80 ? '...' : ''),
        });
      }
      // Reset regex lastIndex for global patterns
      pattern.lastIndex = 0;
    });
  });

  return issues;
}

function getStagedFiles() {
  try {
    const output = execSync('git diff --cached --name-only --diff-filter=ACM', {
      encoding: 'utf-8',
    });
    return output.trim().split('\n').filter(Boolean);
  } catch {
    // If not in a git repo or no staged files, return empty
    return [];
  }
}

function main() {
  const stagedFiles = getStagedFiles();

  if (stagedFiles.length === 0) {
    console.log('No staged files to check.');
    process.exit(0);
  }

  const allIssues = [];

  stagedFiles.forEach(file => {
    const issues = checkFileForCredentials(file);
    allIssues.push(...issues);
  });

  if (allIssues.length > 0) {
    console.error('\n🚨 POTENTIAL CREDENTIALS DETECTED!\n');
    console.error('The following files may contain sensitive credentials:\n');

    allIssues.forEach(issue => {
      console.error(`  ${issue.file}:${issue.line}`);
      console.error(`    Type: ${issue.type}`);
      console.error(`    Content: ${issue.content}\n`);
    });

    console.error('Please remove or redact these credentials before committing.');
    console.error('If these are intentional (e.g., test fixtures), ensure they use');
    console.error('placeholder values like [REDACTED] or example.com\n');

    process.exit(1);
  }

  console.log('✅ No credential leaks detected in staged files.');
  process.exit(0);
}

main();
