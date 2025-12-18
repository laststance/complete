// @ts-check
const esbuild = require('esbuild');

const production = process.argv.includes('--production');
const watch = process.argv.includes('--watch');

/**
 * ESBuild configuration for VSCode extension
 *
 * Key settings:
 * - external: ['vscode'] - VSCode API provided at runtime
 * - format: 'cjs' - CommonJS required for VSCode extensions
 * - platform: 'node' - Node.js runtime environment
 */
async function main() {
  /** @type {import('esbuild').BuildOptions} */
  const buildOptions = {
    entryPoints: ['./src/extension.ts'],
    bundle: true,
    outfile: './dist/extension.js',
    external: ['vscode'],
    format: 'cjs',
    platform: 'node',
    target: 'node20',
    sourcemap: !production,
    minify: production,
    treeShaking: true,
    logLevel: 'info',
  };

  if (watch) {
    const ctx = await esbuild.context(buildOptions);
    await ctx.watch();
    console.log('Watching for changes...');
  } else {
    await esbuild.build(buildOptions);
    console.log('Build complete.');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
