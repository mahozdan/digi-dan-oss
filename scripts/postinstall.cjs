/**
 * Post-install setup hook — runs automatically after npm install.
 * Checks environment and prints setup reminders.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function checkCommand(cmd) {
  try {
    execSync(`${cmd} --version`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function main() {
  const warnings = [];

  // Check for system tools
  if (!checkCommand('semgrep')) {
    warnings.push('semgrep is not installed. Install via: pip install semgrep (or brew install semgrep)');
  }

  // Check for husky setup
  const huskyDir = path.join(process.cwd(), '.husky');
  if (!fs.existsSync(huskyDir)) {
    warnings.push('Husky not initialized. Run: npx husky init');
  }

  if (warnings.length > 0) {
    console.log('\n--- Post-install reminders ---');
    warnings.forEach((w) => console.log(`  ! ${w}`));
    console.log('');
  }
}

main();
