#!/usr/bin/env node

/**
 * Coverage Report Script
 * Runs unit tests with coverage and displays a clean summary
 * Only measures source code files (excludes tests, configs, scripts)
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const ROOT_DIR = path.join(__dirname, '..');
const CLI_DIR = path.join(ROOT_DIR, 'packages', 'codehound-cli');
const COVERAGE_JSON = path.join(CLI_DIR, 'coverage', 'coverage-summary.json');

// Color codes for output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
};

function colorize(text, color) {
  return `${color}${text}${colors.reset}`;
}

function getStatusColor(percentage, threshold) {
  if (percentage >= threshold) return colors.green;
  if (percentage >= threshold - 5) return colors.yellow;
  return colors.red;
}

function formatPercentage(value, threshold) {
  const color = getStatusColor(value, threshold);
  const status = value >= threshold ? '✓' : '✗';
  return `${color}${status} ${value.toFixed(1)}%${colors.reset}`;
}

console.log('\n' + colorize('═'.repeat(70), colors.cyan));
console.log(colorize('  Unit Test Coverage Report', colors.bold + colors.cyan));
console.log(colorize('═'.repeat(70), colors.cyan) + '\n');

console.log(colorize('Running tests with coverage...', colors.dim));
console.log(colorize('This may take a moment...', colors.dim) + '\n');

try {
  // Run coverage with --reporter=json to get structured output
  execSync('npm run test:coverage', {
    cwd: ROOT_DIR,
    stdio: 'pipe',
    encoding: 'utf-8',
  });

  // Check if coverage JSON exists
  if (!fs.existsSync(COVERAGE_JSON)) {
    console.error(colorize('✗ Coverage report not found', colors.red));
    console.error(colorize(`  Expected at: ${COVERAGE_JSON}`, colors.dim));
    process.exit(1);
  }

  // Read coverage data
  const coverageData = JSON.parse(fs.readFileSync(COVERAGE_JSON, 'utf-8'));
  const totals = coverageData.total;

  if (!totals) {
    console.error(colorize('✗ Invalid coverage data format', colors.red));
    process.exit(1);
  }

  // Extract metrics
  const statements = totals.statements.pct;
  const branches = totals.branches.pct;
  const functions = totals.functions.pct;
  const lines = totals.lines.pct;

  // Thresholds from vitest.config.ts
  const thresholds = {
    statements: 80,
    branches: 70,
    functions: 80,
    lines: 80,
  };

  // Calculate overall pass/fail
  const allPass = statements >= thresholds.statements &&
                  branches >= thresholds.branches &&
                  functions >= thresholds.functions &&
                  lines >= thresholds.lines;

  // Display summary table
  console.log(colorize('╭─────────────────────────────────────────────────────────────────────╮', colors.cyan));
  console.log(colorize('│', colors.cyan) + '  ' + colorize('Coverage Summary', colors.bold) + ' '.repeat(50) + colorize('│', colors.cyan));
  console.log(colorize('├─────────────────────────────────────────────────────────────────────┤', colors.cyan));

  console.log(
    colorize('│', colors.cyan) +
    '  Statements   ' +
    formatPercentage(statements, thresholds.statements) +
    ' '.repeat(10) +
    colorize(`(threshold: ${thresholds.statements}%)`, colors.dim) +
    ' '.repeat(20) +
    colorize('│', colors.cyan)
  );

  console.log(
    colorize('│', colors.cyan) +
    '  Branches     ' +
    formatPercentage(branches, thresholds.branches) +
    ' '.repeat(10) +
    colorize(`(threshold: ${thresholds.branches}%)`, colors.dim) +
    ' '.repeat(20) +
    colorize('│', colors.cyan)
  );

  console.log(
    colorize('│', colors.cyan) +
    '  Functions    ' +
    formatPercentage(functions, thresholds.functions) +
    ' '.repeat(10) +
    colorize(`(threshold: ${thresholds.functions}%)`, colors.dim) +
    ' '.repeat(20) +
    colorize('│', colors.cyan)
  );

  console.log(
    colorize('│', colors.cyan) +
    '  Lines        ' +
    formatPercentage(lines, thresholds.lines) +
    ' '.repeat(10) +
    colorize(`(threshold: ${thresholds.lines}%)`, colors.dim) +
    ' '.repeat(20) +
    colorize('│', colors.cyan)
  );

  console.log(colorize('├─────────────────────────────────────────────────────────────────────┤', colors.cyan));

  // Average coverage
  const avgCoverage = (statements + branches + functions + lines) / 4;
  const avgColor = getStatusColor(avgCoverage, 80);
  console.log(
    colorize('│', colors.cyan) +
    '  ' +
    colorize('Average Coverage:', colors.bold) +
    ' ' +
    colorize(`${avgCoverage.toFixed(1)}%`, avgColor + colors.bold) +
    ' '.repeat(40) +
    colorize('│', colors.cyan)
  );

  console.log(colorize('╰─────────────────────────────────────────────────────────────────────╯', colors.cyan));

  // Overall status
  console.log('');
  if (allPass) {
    console.log(colorize('✓ All coverage thresholds met!', colors.bold + colors.green));
  } else {
    console.log(colorize('✗ Some coverage thresholds not met', colors.bold + colors.red));
    console.log('');
    console.log(colorize('Coverage below threshold:', colors.yellow));
    if (statements < thresholds.statements) {
      console.log(colorize(`  • Statements: ${statements.toFixed(1)}% (need ${thresholds.statements}%)`, colors.red));
    }
    if (branches < thresholds.branches) {
      console.log(colorize(`  • Branches: ${branches.toFixed(1)}% (need ${thresholds.branches}%)`, colors.red));
    }
    if (functions < thresholds.functions) {
      console.log(colorize(`  • Functions: ${functions.toFixed(1)}% (need ${thresholds.functions}%)`, colors.red));
    }
    if (lines < thresholds.lines) {
      console.log(colorize(`  • Lines: ${lines.toFixed(1)}% (need ${thresholds.lines}%)`, colors.red));
    }
  }

  // Coverage scope information
  console.log('');
  console.log(colorize('Coverage Scope:', colors.cyan));
  console.log(colorize('  ✓ Includes: src/**/*.ts', colors.dim));
  console.log(colorize('  ✗ Excludes: CLI entry points, commands, wizard', colors.dim));
  console.log(colorize('  ✗ Excludes: Test files, configs, scripts', colors.dim));

  // Detailed report location
  console.log('');
  console.log(colorize('Detailed Reports:', colors.cyan));
  console.log(colorize(`  • HTML: ${path.join('packages', 'codehound-cli', 'coverage', 'index.html')}`, colors.dim));
  console.log(colorize(`  • JSON: ${path.join('packages', 'codehound-cli', 'coverage', 'coverage-summary.json')}`, colors.dim));

  console.log('');

  // Exit with appropriate code
  process.exit(allPass ? 0 : 1);

} catch (error) {
  console.error(colorize('\n✗ Failed to generate coverage report', colors.bold + colors.red));
  console.error(colorize(error.message, colors.red));

  if (error.stdout) {
    console.error('\n' + colorize('Output:', colors.yellow));
    console.error(error.stdout);
  }

  if (error.stderr) {
    console.error('\n' + colorize('Errors:', colors.red));
    console.error(error.stderr);
  }

  process.exit(1);
}
