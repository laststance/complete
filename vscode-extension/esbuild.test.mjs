/**
 * esbuild configuration for test files
 *
 * Bundles test files with CJS format.
 */
import * as esbuild from 'esbuild';
import { glob } from 'glob';

// Find all test files
const testFiles = await glob('test/**/*.test.ts');
const indexFile = 'test/suite/index.ts';

// Bundle each test file
for (const file of [...testFiles, indexFile]) {
  const outfile = file
    .replace(/^test\//, 'dist/test/')
    .replace(/\.ts$/, '.js');

  await esbuild.build({
    entryPoints: [file],
    bundle: true,
    outfile,
    platform: 'node',
    format: 'cjs',
    sourcemap: true,
    external: ['vscode', 'mocha'],
  });
}

console.log('✅ Test files compiled');
