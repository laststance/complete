/**
 * Test Suite Entry Point
 *
 * This file is the entry point for the VSCode extension test suite.
 * It uses Mocha as the test framework with TDD-style assertions.
 *
 * @module test/suite/index
 */

import * as path from 'path';
import Mocha from 'mocha';
import { glob } from 'glob';

/**
 * Run the test suite
 *
 * Discovers all *.test.js files in the test/suite directory
 * and runs them using Mocha.
 */
export async function run(): Promise<void> {
  // Create the mocha test runner
  const mocha = new Mocha({
    ui: 'tdd',
    color: true,
    timeout: 10000,
  });

  const testsRoot = path.resolve(__dirname, '.');

  // Find all test files
  const files = await glob('**/*.test.js', { cwd: testsRoot });

  // Add files to the test suite
  for (const file of files) {
    mocha.addFile(path.resolve(testsRoot, file));
  }

  // Run the tests
  return new Promise((resolve, reject) => {
    mocha.run((failures) => {
      if (failures > 0) {
        reject(new Error(`${failures} tests failed.`));
      } else {
        resolve();
      }
    });
  });
}
