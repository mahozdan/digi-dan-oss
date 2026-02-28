// scripts/failed-only-vitest-reporter.ts
import type { Reporter, TestModule, TestCase } from 'vitest/node'

// ANSI color codes
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  reset: '\x1b[0m',
}

interface FailedTest {
  name: string
  file: string
}

class FailedOnlyReporter implements Reporter {
  private testCount = 0
  private passedCount = 0
  private failedCount = 0

  onTestRunStart() {
    process.stdout.write('Running tests ')
  }

  onTestCaseResult(testCase: TestCase) {
    this.testCount++
    const result = testCase.result()

    if (result.state === 'passed') {
      this.passedCount++
      process.stdout.write(`${colors.green}.${colors.reset}`)
    } else if (result.state === 'failed') {
      this.failedCount++
      process.stdout.write(`${colors.red}x${colors.reset}`)
    } else if (result.state === 'skipped') {
      process.stdout.write(`${colors.yellow}-${colors.reset}`)
    }

    // Line break every 50 tests for readability
    if (this.testCount % 50 === 0) {
      process.stdout.write(` [${this.testCount}]\n               `)
    }
  }

  onTestRunEnd(testModules: ReadonlyArray<TestModule>) {
    // End the progress line
    process.stdout.write(` [${this.testCount}]\n`)
    let totalTests = 0
    let failedTests = 0
    const failures: FailedTest[] = []

    for (const mod of testModules) {
      // Use the children.allTests() iterator from Vitest 3.x API
      for (const test of mod.children.allTests()) {
        totalTests++
        const result = test.result()

        if (result.state === 'failed') {
          failedTests++

          // Build full test path including parent suites
          const nameParts: string[] = []
          let current: TestCase | { name: string; parent?: unknown } | undefined = test
          while (current) {
            if (current.name) {
              nameParts.unshift(current.name)
            }
            current = 'parent' in current ? (current.parent as typeof current) : undefined
          }

          failures.push({
            name: nameParts.join(' > '),
            file: mod.moduleId,
          })
        }
      }
    }

    if (failedTests > 0) {
      console.log('\n=== Failed Tests ===\n')

      for (const failure of failures) {
        console.log(`${colors.red}FAIL${colors.reset} ${failure.file}`)
        console.log(`  ${failure.name}\n`)
      }

      const failurePct = totalTests > 0 ? (failedTests / totalTests) * 100 : 0

      console.log('=== Summary ===')
      console.log(`Total tests: ${totalTests}`)
      console.log(`Failed     : ${failedTests}`)
      console.log(`Failure %  : ${failurePct.toFixed(2)}%`)

      // Print copy-paste ready command to re-run failed tests
      const uniqueFiles = [...new Set(failures.map((f) => f.file))]
      console.log('\n=== Re-run failed tests ===')
      console.log(`npx vitest run --coverage=false ${uniqueFiles.join(' ')} --reporter=dot --silent`)
    } else {
      console.log('\nAll tests passed!\n')
    }
  }
}

export default FailedOnlyReporter
