#!/usr/bin/env node

/**
 * Definition of Done (DoD) Check Script
 * Runs all quality checks and provides a concise summary
 *
 * Usage: node scripts/dod.cjs [skip|core|all]
 * Or:    SFS_CHECKS=skip node scripts/dod.cjs
 *
 * Levels:
 *   skip  - Skip all DoD checks
 *   core  - Run only critical checks (build, test, coverage, lint, format)
 *   all   - Run all checks (default)
 */

const {
  execSync
} = require('child_process');
const path = require('path');
const fs = require('fs');

const ROOT_DIR = path.join(__dirname, '..');

// Check level from command line argument or environment variable
const CHECK_LEVEL = (process.argv[2] || process.env.SFS_CHECKS || 'all').toLowerCase();

if (CHECK_LEVEL === 'skip') {
  console.log('\n⚠️  SFS_CHECKS=skip - Skipping all DoD checks\n');
  process.exit(0);
}

const RUN_CORE_ONLY = CHECK_LEVEL === 'core';

// Color codes for output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function exec(command, silent = true) {
  try {
    // nosemgrep: javascript.lang.security.detect-child-process.detect-child-process
    return execSync(command, {
      cwd: ROOT_DIR,
      encoding: 'utf-8',
      stdio: silent ? 'pipe' : 'inherit',
    });
  } catch (error) {
    if (silent && error.stdout) {
      return error.stdout + (error.stderr || '');
    }
    throw error;
  }
}

// Coverage threshold (percentage)
const COVERAGE_THRESHOLD = 95;

// Check results storage
const results = {
  build: {
    pass: false,
    message: ''
  },
  longfiles: {
    pass: false,
    message: ''
  },
  test: {
    pass: false,
    message: ''
  },
  coverage: {
    pass: false,
    message: ''
  },
  lint: {
    pass: false,
    message: ''
  },
  format: {
    pass: false,
    message: ''
  },
  syncpack: {
    pass: false,
    message: ''
  },
  knip: {
    pass: false,
    message: ''
  },
  seccheck: {
    pass: false,
    message: ''
  },
  audit: {
    pass: false,
    message: ''
  },
};

console.log('\n' + colors.bold + colors.cyan + '='.repeat(60));
console.log('  Definition of Done (DoD) Quality Gate Check');
if (RUN_CORE_ONLY) {
  console.log('  Mode: CORE ONLY (critical checks only)');
}
console.log('='.repeat(60) + colors.reset + '\n');

// 1. Build Check
process.stdout.write('⏳ Build check...');
try {
  exec('npm run build');
  results.build.pass = true;
  results.build.message = 'Compilation successful';
  process.stdout.write('\r✅ Build check       ' + colors.green + 'PASS' + colors.reset + '\n');
} catch (error) {
  results.build.message = 'Compilation failed';
  process.stdout.write('\r❌ Build check       ' + colors.red + 'FAIL' + colors.reset + '\n');
}

// 2. Long Files Check (files > 300 lines in src/) - Warning check
if (RUN_CORE_ONLY) {
  results.longfiles.pass = true;
  results.longfiles.message = 'Skipped (core mode)';
  console.log('⏭️  Long files check  ' + colors.yellow + 'SKIP' + colors.reset + ' (core mode)');
} else {
  process.stdout.write('⏳ Long files check...');
  try {
    const srcDir = path.join(ROOT_DIR, 'src');
    let longFileCount = 0;
    const longFiles = [];

    function checkDir(dir) {
      const entries = fs.readdirSync(dir, {
        withFileTypes: true
      });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          checkDir(fullPath);
        } else if (entry.name.endsWith('.ts') || entry.name.endsWith('.js')) {
          const content = fs.readFileSync(fullPath, 'utf-8');
          const lineCount = content.split('\n').length;
          if (lineCount > 300) {
            longFileCount++;
            longFiles.push({
              path: fullPath.replace(ROOT_DIR + path.sep, ''),
              lines: lineCount
            });
          }
        }
      }
    }

    checkDir(srcDir);

    results.longfiles.pass = longFileCount === 0;
    results.longfiles.message =
      longFileCount === 0 ?
      'No files exceed 300 lines' :
      `${longFileCount} file${longFileCount > 1 ? 's' : ''} exceed 300 lines`;

    if (longFileCount > 0) {
      results.longfiles.details = longFiles;
    }

    process.stdout.write(
      '\r✅ Long files check  ' +
      (results.longfiles.pass ? colors.green + 'PASS' : colors.yellow + 'WARN') +
      colors.reset +
      ` (${longFileCount} long files)\n`
    );
  } catch (error) {
    results.longfiles.message = 'Check failed';
    process.stdout.write('\r❌ Long files check  ' + colors.red + 'FAIL' + colors.reset + '\n');
  }
}

// 3. Test Check
process.stdout.write('⏳ Test check...');
try {
  const output = exec('npm test -- --run');

  // Parse test results from vitest
  const passMatch = output.match(/(\d+)\s+passed/);
  const failMatch = output.match(/(\d+)\s+failed/);
  const passed = passMatch ? parseInt(passMatch[1]) : 0;
  const failed = failMatch ? parseInt(failMatch[1]) : 0;

  results.test.pass = failed === 0 && passed > 0;
  results.test.message = `${passed} passed, ${failed} failed`;

  process.stdout.write(
    '\r✅ Test check        ' +
    (results.test.pass ? colors.green + 'PASS' : colors.red + 'FAIL') +
    colors.reset +
    ` (${passed} passed, ${failed} failed)\n`
  );
} catch (error) {
  results.test.message = 'Tests failed';
  process.stdout.write('\r❌ Test check        ' + colors.red + 'FAIL' + colors.reset + '\n');
}

// 4. Coverage Check
process.stdout.write('⏳ Coverage check...');
try {
  const covOutput = exec('npm run test:coverage 2>&1');

  // Parse coverage from vitest v8 output: "All files |  XX.XX | ..."
  const covMatch = covOutput.match(/All files\s*\|\s*([\d.]+)/);
  let covPercent = 0;

  if (covMatch) {
    covPercent = parseFloat(covMatch[1]);
  } else {
    // Alternative: "Statements : XX.XX%"
    const stmtMatch = covOutput.match(/Statements\s*:\s*([\d.]+)%/);
    if (stmtMatch) {
      covPercent = parseFloat(stmtMatch[1]);
    }
  }

  results.coverage.pass = covPercent >= COVERAGE_THRESHOLD;
  results.coverage.message = `${covPercent.toFixed(1)}% (threshold: ${COVERAGE_THRESHOLD}%)`;

  process.stdout.write(
    '\r' +
    (results.coverage.pass ? '✅' : '❌') +
    ' Coverage check    ' +
    (results.coverage.pass ? colors.green + 'PASS' : colors.red + 'FAIL') +
    colors.reset +
    ` (${covPercent.toFixed(1)}% >= ${COVERAGE_THRESHOLD}%)\n`
  );
} catch (error) {
  const covOutput = error.stdout || error.stderr || '';
  const covMatch = covOutput.match(/All files\s*\|\s*([\d.]+)/);

  if (covMatch) {
    const covPercent = parseFloat(covMatch[1]);
    results.coverage.pass = covPercent >= COVERAGE_THRESHOLD;
    results.coverage.message = `${covPercent.toFixed(1)}% (threshold: ${COVERAGE_THRESHOLD}%)`;
    process.stdout.write(
      '\r' +
      (results.coverage.pass ? '✅' : '❌') +
      ' Coverage check    ' +
      (results.coverage.pass ? colors.green + 'PASS' : colors.red + 'FAIL') +
      colors.reset +
      ` (${covPercent.toFixed(1)}% >= ${COVERAGE_THRESHOLD}%)\n`
    );
  } else {
    results.coverage.message = 'Coverage check failed';
    process.stdout.write('\r❌ Coverage check    ' + colors.red + 'FAIL' + colors.reset + '\n');
  }
}

// 5. Lint Check
process.stdout.write('⏳ Lint check...');
try {
  exec('npm run lint');
  results.lint.pass = true;
  results.lint.message = 'No linting errors';
  process.stdout.write('\r✅ Lint check        ' + colors.green + 'PASS' + colors.reset + '\n');
} catch (error) {
  const output = error.stdout || error.stderr || '';
  const errorMatch = output.match(/(\d+)\s+error/);
  const warningMatch = output.match(/(\d+)\s+warning/);
  const errors = errorMatch ? parseInt(errorMatch[1]) : 0;
  const warnings = warningMatch ? parseInt(warningMatch[1]) : 0;

  results.lint.message = `${errors} error${errors !== 1 ? 's' : ''}, ${warnings} warning${warnings !== 1 ? 's' : ''}`;
  process.stdout.write(
    '\r❌ Lint check        ' +
    colors.red +
    'FAIL' +
    colors.reset +
    ` (${errors} errors, ${warnings} warnings)\n`
  );
}

// 6. Format Check (Prettier)
process.stdout.write('⏳ Format check...');
try {
  exec('npx prettier --check "src/**/*.ts"');
  results.format.pass = true;
  results.format.message = 'All files formatted correctly';
  process.stdout.write('\r✅ Format check      ' + colors.green + 'PASS' + colors.reset + '\n');
} catch (error) {
  const output = error.stdout || error.stderr || '';
  const unformattedCount = (output.match(/\[warn\]/g) || []).length;

  results.format.pass = false;
  results.format.message =
    unformattedCount > 0 ?
    `${unformattedCount} file${unformattedCount !== 1 ? 's' : ''} need formatting` :
    'Files need formatting';
  process.stdout.write(
    '\r❌ Format check      ' + colors.red + 'FAIL' + colors.reset + ` (run: npm run format)\n`
  );
}

// 7. Syncpack Check (package.json consistency) - Warning check
process.stdout.write('⏳ Syncpack check...');
try {
  exec('npx syncpack lint');
  results.syncpack.pass = true;
  results.syncpack.message = 'Package.json is consistent';
  process.stdout.write('\r✅ Syncpack check    ' + colors.green + 'PASS' + colors.reset + '\n');
} catch (error) {
  const output = error.stdout || error.stderr || '';
  const hasErrors = output.includes('error') || output.includes('✘') || output.includes('Error');

  results.syncpack.pass = false;
  results.syncpack.message = hasErrors
    ? 'Package.json consistency issues found (run: npm run syncpack:fix)'
    : 'Package.json consistency issues found';
  process.stdout.write(
    '\r⚠️  Syncpack check    ' + colors.yellow + 'WARN' + colors.reset + ' (run: npm run syncpack:fix)\n'
  );
}

// 8. Knip Check (unused exports, dependencies, files) - Warning check

if (RUN_CORE_ONLY) {
  results.knip.pass = true;
  results.knip.message = 'Skipped (core mode)';
  console.log('⏭️  Knip check        ' + colors.yellow + 'SKIP' + colors.reset + ' (core mode)');
} else {
  process.stdout.write('⏳ Knip check...');
  try {
    const output = exec('npx knip');

    const hasIssues =
      output.includes('Unused') ||
      output.includes('unused') ||
      output.includes('Missing') ||
      output.includes('Unlisted');

    results.knip.pass = !hasIssues;
    results.knip.message = hasIssues ? 'Unused code or dependencies found' : 'No unused code detected';

    process.stdout.write(
      '\r✅ Knip check        ' +
      (results.knip.pass ? colors.green + 'PASS' : colors.yellow + 'WARN') +
      colors.reset +
      '\n'
    );
  } catch (error) {
    results.knip.pass = false;
    results.knip.message = 'Unused code or dependencies found';
    process.stdout.write('\r⚠️  Knip check        ' + colors.yellow + 'WARN' + colors.reset + '\n');
  }
}

// 9. Security Check (semgrep) - Warning check
if (RUN_CORE_ONLY) {
  results.seccheck.pass = true;
  results.seccheck.message = 'Skipped (core mode)';
  console.log('⏭️  Security check    ' + colors.yellow + 'SKIP' + colors.reset + ' (core mode)');
} else {
  process.stdout.write('⏳ Security check...');
  try {
    const output = exec('npx semgrep --config semgrep.yml src/ 2>&1', true);

    const findingsMatch = output.match(/Findings:\s+(\d+)/i);
    const findings = findingsMatch ? parseInt(findingsMatch[1]) : 0;

    results.seccheck.pass = findings === 0;
    results.seccheck.message =
      findings === 0 ? 'No security issues found' : `${findings} security finding${findings > 1 ? 's' : ''}`;

    process.stdout.write(
      '\r✅ Security check    ' +
      (results.seccheck.pass ? colors.green + 'PASS' : colors.yellow + 'WARN') +
      colors.reset +
      ` (${findings} findings)\n`
    );
  } catch (error) {
    results.seccheck.pass = true;
    results.seccheck.message = 'Semgrep not available (install with: pip install semgrep)';
    process.stdout.write(
      '\r⚠️  Security check    ' + colors.yellow + 'SKIP' + colors.reset + ' (semgrep not installed)\n'
    );
  }
}

// 10. Audit Check - Warning check
if (RUN_CORE_ONLY) {
  results.audit.pass = true;
  results.audit.message = 'Skipped (core mode)';
  console.log('⏭️  Audit check       ' + colors.yellow + 'SKIP' + colors.reset + ' (core mode)');
} else {
  process.stdout.write('⏳ Audit check...');
  try {
    const output = exec('npm audit 2>&1');

    const vulnMatch = output.match(/found\s+(\d+)\s+vulnerabilit/);
    const vulnerabilities = vulnMatch ? parseInt(vulnMatch[1]) : 0;

    let severity = '';
    if (vulnerabilities > 0) {
      const severities = [];
      const critMatch = output.match(/(\d+)\s+critical/);
      const highMatch = output.match(/(\d+)\s+high/);
      const modMatch = output.match(/(\d+)\s+moderate/);
      const lowMatch = output.match(/(\d+)\s+low/);
      if (critMatch && parseInt(critMatch[1]) > 0) severities.push(`${critMatch[1]} critical`);
      if (highMatch && parseInt(highMatch[1]) > 0) severities.push(`${highMatch[1]} high`);
      if (modMatch && parseInt(modMatch[1]) > 0) severities.push(`${modMatch[1]} moderate`);
      if (lowMatch && parseInt(lowMatch[1]) > 0) severities.push(`${lowMatch[1]} low`);
      severity = severities.join(', ');
    }

    results.audit.pass = vulnerabilities === 0;
    results.audit.message =
      vulnerabilities === 0 ? 'No vulnerabilities' : `${vulnerabilities} vulnerabilities (${severity})`;

    process.stdout.write(
      '\r✅ Audit check       ' +
      (results.audit.pass ? colors.green + 'PASS' : colors.yellow + 'WARN') +
      colors.reset +
      ` (${vulnerabilities} vulnerabilities)\n`
    );
  } catch (error) {
    const output = error.stdout || error.stderr || '';
    const vulnMatch = output.match(/found\s+(\d+)\s+vulnerabilit/);
    const vulnerabilities = vulnMatch ? parseInt(vulnMatch[1]) : 0;

    results.audit.pass = vulnerabilities === 0;
    results.audit.message = vulnerabilities > 0 ? `${vulnerabilities} vulnerabilities` : 'Audit check failed';
    process.stdout.write(
      '\r⚠️  Audit check       ' +
      colors.yellow +
      'WARN' +
      colors.reset +
      ` (${vulnerabilities} vulnerabilities)\n`
    );
  }
}

// Summary
console.log('\n' + colors.bold + '─'.repeat(60) + colors.reset);

const criticalChecks = ['build', 'test', 'coverage', 'lint', 'format'];
const criticalPassed = criticalChecks.every((check) => results[check].pass);

const warningChecks = ['longfiles', 'syncpack', 'knip', 'seccheck', 'audit'];
const warningsPassed = warningChecks.every((check) => results[check].pass);

if (criticalPassed && warningsPassed) {
  log('✅ ALL CHECKS PASSED - Ready to commit!', colors.bold + colors.green);
} else if (criticalPassed) {
  log('⚠️  CRITICAL CHECKS PASSED (with warnings)', colors.bold + colors.yellow);
  console.log('\nWarnings:');
  warningChecks.forEach((check) => {
    if (!results[check].pass) {
      log(`  • ${check}: ${results[check].message}`, colors.yellow);
    }
  });
} else {
  log('❌ CRITICAL CHECKS FAILED - Fix issues before commit', colors.bold + colors.red);
  console.log('\nFailed checks:');
  criticalChecks.forEach((check) => {
    if (!results[check].pass) {
      log(`  • ${check}: ${results[check].message}`, colors.red);
    }
  });
  if (!warningsPassed) {
    console.log('\nWarnings:');
    warningChecks.forEach((check) => {
      if (!results[check].pass) {
        log(`  • ${check}: ${results[check].message}`, colors.yellow);
      }
    });
  }
}

// Show long files details if any
if (results.longfiles.details && results.longfiles.details.length > 0) {
  console.log('\nLong files (>300 lines):');
  results.longfiles.details.forEach((f) => {
    log(`  • ${f.path} (${f.lines} lines)`, colors.yellow);
  });
}

console.log(colors.bold + '─'.repeat(60) + colors.reset + '\n');

// Exit with appropriate code (only fail on critical checks)
process.exit(criticalPassed ? 0 : 1);
