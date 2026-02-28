#!/usr/bin/env node

/**
 * Publish Script
 *
 * This script automates the npm publishing process:
 * 1. Checks npm login status
 * 2. Runs tests and builds
 * 3. Analyzes git changes to suggest version bump
 * 4. Prompts for version update
 * 5. Publishes to npm
 *
 * Usage: node scripts/publish-to-npm.js [--otp]
 *
 * Options:
 *   --otp    Force OTP mode (skip token, prompt for 2FA code)
 */

const USE_OTP = process.argv.includes('--otp');

import {
    execSync,
    spawnSync
} from 'child_process';
import {
    createInterface
} from 'readline';
import {
    readFileSync,
    writeFileSync,
    existsSync,
    unlinkSync
} from 'fs';
import {
    join,
    dirname
} from 'path';
import {
    fileURLToPath
} from 'url';

const __filename = fileURLToPath(
    import.meta.url);
const __dirname = dirname(__filename);
const ROOT_DIR = join(__dirname, '..');
const CLI_DIR = join(ROOT_DIR);
const ENV_FILE = join(ROOT_DIR, '.env');

// Read package name from package.json
const PACKAGE_NAME = JSON.parse(readFileSync(join(CLI_DIR, 'package.json'), 'utf-8')).name;

function detectPackageManager() {
    const lockFiles = [
        { file: 'pnpm-lock.yaml', pm: 'pnpm' },
        { file: 'yarn.lock', pm: 'yarn' },
        { file: 'bun.lockb', pm: 'bun' },
        { file: 'package-lock.json', pm: 'npm' },
    ];

    for (const { file, pm } of lockFiles) {
        if (existsSync(join(ROOT_DIR, file))) {
            return pm;
        }
    }

    return 'npm';
}

const PM = detectPackageManager();

function loadEnvToken() {
    if (!existsSync(ENV_FILE)) {
        return null;
    }

    try {
        const envContent = readFileSync(ENV_FILE, 'utf-8');
        const match = envContent.match(/NPM_PUBLISH_TOKEN\s*=\s*["']?([^"'\n]+)["']?/);
        return match ? match[1].trim() : null;
    } catch {
        return null;
    }
}

// ANSI colors
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    bold: '\x1b[1m',
};

function log(message, color = '') {
    console.log(`${color}${message}${colors.reset}`);
}

function logStep(step, message) {
    log(`\n[${step}] ${message}`, colors.cyan + colors.bold);
}

function logSuccess(message) {
    log(`✓ ${message}`, colors.green);
}

function logError(message) {
    log(`✗ ${message}`, colors.red);
}

function logWarning(message) {
    log(`⚠ ${message}`, colors.yellow);
}

function exec(command, options = {}) {
    try {
        // nosemgrep: javascript.lang.security.detect-child-process.detect-child-process
        return execSync(command, {
            encoding: 'utf-8',
            stdio: options.silent ? 'pipe' : 'inherit',
            cwd: options.cwd || ROOT_DIR,
            ...options,
        });
    } catch (error) {
        if (options.ignoreError) {
            return error.stdout || '';
        }
        throw error;
    }
}

function execSilent(command, options = {}) {
    return exec(command, {
        ...options,
        silent: true,
        stdio: 'pipe'
    });
}

async function prompt(question) {
    const rl = createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    return new Promise((resolve) => {
        rl.question(question, (answer) => {
            rl.close();
            resolve(answer.trim());
        });
    });
}

async function promptChoice(question, choices) {
    console.log(`\n${colors.bold}${question}${colors.reset}`);
    choices.forEach((choice, index) => {
        console.log(`  ${index + 1}) ${choice.label}${choice.recommended ? ' (Recommended)' : ''}`);
    });

    while (true) {
        const answer = await prompt(`\nEnter choice (1-${choices.length}): `);
        const index = parseInt(answer, 10) - 1;
        if (index >= 0 && index < choices.length) {
            return choices[index].value;
        }
        logWarning('Invalid choice. Please try again.');
    }
}

function checkNpmLogin() {
    logStep('1/6', 'Checking npm login status...');

    try {
        const username = execSilent('npm whoami').trim();
        logSuccess(`Logged in as: ${username}`);
        return true;
    } catch {
        logWarning('Not logged in to npm.');
        return false;
    }
}

async function handleNpmLogin() {
    log('\nYou need to log in to npm to publish packages.');
    log('Running: npm login\n', colors.cyan);

    // nosemgrep: javascript.lang.security.audit.spawn-shell-true.spawn-shell-true
    const result = spawnSync('npm', ['login'], {
        stdio: 'inherit',
        shell: true,
    });

    if (result.status !== 0) {
        logError('npm login failed. Please try again.');
        process.exit(1);
    }

    // Verify login succeeded
    try {
        const username = execSilent('npm whoami').trim();
        logSuccess(`Successfully logged in as: ${username}`);
        return true;
    } catch {
        logError('Login verification failed. Please try again.');
        process.exit(1);
    }
}

function runTests() {
    logStep('2/6', `Running tests (${PM})...`);

    try {
        exec(`${PM} run test:unit`);
        logSuccess('All tests passed.');
    } catch {
        logError('Tests failed. Please fix the issues before publishing.');
        process.exit(1);
    }
}

function buildProject() {
    logStep('3/6', `Building project (${PM})...`);

    try {
        exec(`${PM} run build`);
        logSuccess('Build completed successfully.');
    } catch {
        logError('Build failed. Please fix the issues before publishing.');
        process.exit(1);
    }
}

function getCurrentVersion() {
    const packagePath = join(CLI_DIR, 'package.json');
    const pkg = JSON.parse(readFileSync(packagePath, 'utf-8'));
    return pkg.version;
}

function getPublishedVersion() {
    try {
        const version = execSilent(`npm view ${PACKAGE_NAME} version`, {
            ignoreError: true
        }).trim();
        return version || null;
    } catch {
        return null;
    }
}

function compareVersions(v1, v2) {
    const parts1 = v1.split('.').map(Number);
    const parts2 = v2.split('.').map(Number);

    for (let i = 0; i < 3; i++) {
        if (parts1[i] > parts2[i]) return 1;
        if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
}

function getLastPublishedTag() {
    try {
        // Try to find the last version tag
        const tags = execSilent('git tag --list "v*" --sort=-v:refname', {
            ignoreError: true
        });
        const tagList = tags.trim().split('\n').filter(Boolean);
        return tagList.length > 0 ? tagList[0] : null;
    } catch {
        return null;
    }
}

function analyzeGitChanges() {
    logStep('4/6', 'Analyzing git changes...');

    const lastTag = getLastPublishedTag();
    const currentVersion = getCurrentVersion();

    log(`Current version: ${currentVersion}`);

    if (!lastTag) {
        logWarning('No previous version tags found. This appears to be the first publish.');
        return {
            isFirstPublish: true,
            commits: [],
            suggestion: 'minor'
        };
    }

    log(`Last published version: ${lastTag}`);

    try {
        // Get commits since last tag
        const commits = execSilent(`git log ${lastTag}..HEAD --oneline`, {
                ignoreError: true
            })
            .trim()
            .split('\n')
            .filter(Boolean);

        if (commits.length === 0) {
            logWarning('No new commits since last publish.');
            return {
                isFirstPublish: false,
                commits: [],
                suggestion: null
            };
        }

        log(`\nChanges since ${lastTag} (${commits.length} commits):`);
        commits.slice(0, 10).forEach((commit) => {
            log(`  • ${commit}`, colors.cyan);
        });
        if (commits.length > 10) {
            log(`  ... and ${commits.length - 10} more commits`);
        }

        // Analyze commit messages for version suggestion
        const commitText = commits.join('\n').toLowerCase();
        let suggestion = 'patch';

        // Check for breaking changes
        if (
            commitText.includes('breaking') ||
            commitText.includes('!:') ||
            commitText.includes('major')
        ) {
            suggestion = 'major';
        }
        // Check for new features
        else if (
            commitText.includes('feat') ||
            commitText.includes('feature') ||
            commitText.includes('add') ||
            commitText.includes('new')
        ) {
            suggestion = 'minor';
        }
        // Default to patch for fixes, refactors, etc.

        return {
            isFirstPublish: false,
            commits,
            suggestion
        };
    } catch (error) {
        logWarning('Could not analyze git history.');
        return {
            isFirstPublish: false,
            commits: [],
            suggestion: 'patch'
        };
    }
}

function bumpVersion(currentVersion, bump) {
    const [major, minor, patch] = currentVersion.split('.').map(Number);

    switch (bump) {
        case 'major':
            return `${major + 1}.0.0`;
        case 'minor':
            return `${major}.${minor + 1}.0`;
        case 'patch':
            return `${major}.${minor}.${patch + 1}`;
        default:
            return currentVersion;
    }
}

async function promptVersionUpdate(analysis, publishedVersion) {
    const currentVersion = getCurrentVersion();

    if (analysis.suggestion === null) {
        const proceed = await prompt('\nNo changes detected. Publish anyway? (y/N): ');
        if (proceed.toLowerCase() !== 'y') {
            log('\nPublish cancelled.');
            process.exit(0);
        }
    }

    // Build choices, filtering out versions that would conflict with published version
    const choices = [];

    const patchVersion = bumpVersion(currentVersion, 'patch');
    const minorVersion = bumpVersion(currentVersion, 'minor');
    const majorVersion = bumpVersion(currentVersion, 'major');

    // Only offer versions higher than published version
    if (!publishedVersion || compareVersions(patchVersion, publishedVersion) > 0) {
        choices.push({
            label: `Patch (${patchVersion}) - Bug fixes`,
            value: 'patch',
            recommended: analysis.suggestion === 'patch',
        });
    }

    if (!publishedVersion || compareVersions(minorVersion, publishedVersion) > 0) {
        choices.push({
            label: `Minor (${minorVersion}) - New features`,
            value: 'minor',
            recommended: analysis.suggestion === 'minor',
        });
    }

    if (!publishedVersion || compareVersions(majorVersion, publishedVersion) > 0) {
        choices.push({
            label: `Major (${majorVersion}) - Breaking changes`,
            value: 'major',
            recommended: analysis.suggestion === 'major',
        });
    }

    // Only offer "keep current" if current version is higher than published
    if (!publishedVersion || compareVersions(currentVersion, publishedVersion) > 0) {
        choices.push({
            label: `Keep current (${currentVersion})`,
            value: 'keep',
            recommended: false,
        });
    }

    if (choices.length === 0) {
        logError(`\nCannot publish: all version options (${currentVersion}, ${patchVersion}, ${minorVersion}, ${majorVersion}) are <= published version ${publishedVersion}`);
        logError('Please manually update the version in package.json to a version higher than ' + publishedVersion);
        process.exit(1);
    }

    // Sort to put recommended first
    choices.sort((a, b) => (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0));

    log(`\nBased on commit analysis, suggested version bump: ${colors.bold}${analysis.suggestion}${colors.reset}`);

    const choice = await promptChoice('Select version update:', choices);

    if (choice === 'keep') {
        return currentVersion;
    }

    const newVersion = bumpVersion(currentVersion, choice);
    return newVersion;
}

function updatePackageVersion(newVersion) {
    const currentVersion = getCurrentVersion();

    if (newVersion === currentVersion) {
        log(`\nKeeping version at ${currentVersion}`);
        return;
    }

    logStep('5/6', `Updating version: ${currentVersion} → ${newVersion}`);

    // Update CLI package.json
    const cliPackagePath = join(CLI_DIR, 'package.json');
    const cliPkg = JSON.parse(readFileSync(cliPackagePath, 'utf-8'));
    cliPkg.version = newVersion;
    writeFileSync(cliPackagePath, JSON.stringify(cliPkg, null, 2) + '\n');

    // Update root package.json
    const rootPackagePath = join(ROOT_DIR, 'package.json');
    const rootPkg = JSON.parse(readFileSync(rootPackagePath, 'utf-8'));
    rootPkg.version = newVersion;
    writeFileSync(rootPackagePath, JSON.stringify(rootPkg, null, 2) + '\n');

    logSuccess(`Updated version to ${newVersion}`);
}

function verifyPackageContents() {
    log('\nVerifying package contents...');

    try {
        const output = execSilent('npm pack --dry-run', {
            cwd: CLI_DIR
        });
        log(output, colors.cyan);
        logSuccess('Package contents verified.');
    } catch (error) {
        logWarning('Could not verify package contents.');
    }
}

async function publishToNpm() {
    logStep('6/6', 'Publishing to npm...');

    const confirmPublish = await prompt('\nReady to publish to npm. Continue? (y/N): ');
    if (confirmPublish.toLowerCase() !== 'y') {
        log('\nPublish cancelled.');
        process.exit(0);
    }

    // Check for automation token in .env file (unless --otp flag is used)
    const token = USE_OTP ? null : loadEnvToken();

    if (token) {
        log('\nUsing NPM_PUBLISH_TOKEN from .env file...', colors.cyan);

        // Create a temporary .npmrc file in the CLI package directory
        const npmrcPath = join(CLI_DIR, '.npmrc');
        const npmrcBackup = existsSync(npmrcPath) ? readFileSync(npmrcPath, 'utf-8') : null;

        try {
            // Write token to .npmrc for authentication
            writeFileSync(npmrcPath, `//registry.npmjs.org/:_authToken=${token}\n`);

            exec('npm publish --access public', {
                cwd: CLI_DIR
            });
            logSuccess('Successfully published to npm!');
        } catch (error) {
            logError('Failed to publish to npm.');
            logError('If using a Publish token, try running with --otp flag instead:');
            log('  node scripts/publish.js --otp', colors.cyan);
            throw error;
        } finally {
            // Restore or remove the .npmrc file
            if (npmrcBackup !== null) {
                writeFileSync(npmrcPath, npmrcBackup);
            } else {
                try {
                    unlinkSync(npmrcPath);
                } catch {
                    // Ignore cleanup errors
                }
            }
        }
    } else {
        // No token found or --otp flag used, prompt for OTP (2FA code)
        if (USE_OTP) {
            log('\nOTP mode enabled (--otp flag).', colors.cyan);
        }
        log('\nTwo-factor authentication is required to publish.', colors.yellow);
        const otp = await prompt('Enter your npm OTP code: ');

        if (!otp || otp.length < 6) {
            logError('Invalid OTP code. Please try again.');
            process.exit(1);
        }

        try {
            exec(`npm publish --access public --otp=${otp}`, {
                cwd: CLI_DIR
            });
            logSuccess('Successfully published to npm!');
        } catch (error) {
            logError('Failed to publish to npm.');
            throw error;
        }
    }
}

function createGitTag(version) {
    const tagName = `v${version}`;

    try {
        // Check if tag already exists
        const existingTags = execSilent('git tag --list', {
            ignoreError: true
        });
        if (existingTags.includes(tagName)) {
            logWarning(`Git tag ${tagName} already exists.`);
            return;
        }

        execSilent(`git tag -a ${tagName} -m "Release ${tagName}"`);
        logSuccess(`Created git tag: ${tagName}`);

        log('\nTo push the tag to remote, run:');
        log(`  git push origin ${tagName}`, colors.cyan);
    } catch (error) {
        logWarning('Could not create git tag.');
    }
}

async function verifyPublication(version) {
    log('\nVerifying publication...');

    try {
        // Wait a moment for npm registry to update
        await new Promise((resolve) => setTimeout(resolve, 2000));

        const info = execSilent(`npm view ${PACKAGE_NAME} version`, {
            ignoreError: true
        }).trim();
        if (info === version) {
            logSuccess(`Verified: ${PACKAGE_NAME}@${version} is live on npm!`);
        } else {
            logWarning('Could not verify publication. It may take a few minutes to appear.');
        }
    } catch {
        logWarning('Could not verify publication.');
    }
}

async function main() {
    log('\n' + '='.repeat(60), colors.cyan);
    log(`  ${PACKAGE_NAME} - npm Publish Script`, colors.cyan + colors.bold);
    log('='.repeat(60) + '\n', colors.cyan);
    log(`  Package manager: ${PM}`, colors.cyan);

    // Step 1: Check npm login
    const isLoggedIn = checkNpmLogin();
    if (!isLoggedIn) {
        await handleNpmLogin();
    }

    // Step 2: Run tests
    runTests();

    // Step 3: Build project
    buildProject();

    // Step 4: Check published version and analyze git changes
    const analysis = analyzeGitChanges();

    // Check currently published version on npm
    log('\nChecking published version on npm...');
    const publishedVersion = getPublishedVersion();
    const currentVersion = getCurrentVersion();

    if (publishedVersion) {
        log(`Published version: ${publishedVersion}`, colors.cyan);
        log(`Local version: ${currentVersion}`, colors.cyan);

        if (compareVersions(currentVersion, publishedVersion) === 0) {
            logWarning(`Local version ${currentVersion} is the same as published version.`);
            logWarning('You must bump the version to publish.');
        } else if (compareVersions(currentVersion, publishedVersion) < 0) {
            logWarning(`Local version ${currentVersion} is lower than published version ${publishedVersion}.`);
            logWarning('You must bump the version to publish.');
        } else {
            logSuccess(`Local version ${currentVersion} is higher than published version ${publishedVersion}.`);
        }
    } else {
        log('Package not yet published to npm (first publish).', colors.yellow);
    }

    // Step 5: Prompt for version update
    const newVersion = await promptVersionUpdate(analysis, publishedVersion);

    // Validate final version against published version
    if (publishedVersion && compareVersions(newVersion, publishedVersion) <= 0) {
        logError(`\nCannot publish version ${newVersion}: must be higher than published version ${publishedVersion}`);
        process.exit(1);
    }

    // Update package version
    updatePackageVersion(newVersion);

    // Verify package contents
    verifyPackageContents();

    // Step 6: Publish to npm
    await publishToNpm();

    // Create git tag
    createGitTag(newVersion);

    // Verify publication
    await verifyPublication(newVersion);

    // Final summary
    log('\n' + '='.repeat(60), colors.green);
    log('  Publication Complete!', colors.green + colors.bold);
    log('='.repeat(60), colors.green);
    log(`\nUsers can now install with:`);
    log(`  npm install -g ${PACKAGE_NAME}`, colors.cyan);
    log(`\nOr update existing installation:`);
    log(`  npm update -g ${PACKAGE_NAME}\n`, colors.cyan);
}

main().catch((error) => {
    logError(`\nPublish failed: ${error.message}`);
    process.exit(1);
});
