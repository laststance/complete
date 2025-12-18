/**
 * SpellEngine Unit Tests
 *
 * Tests for the spell engine service using cspell-lib.
 *
 * @module test/suite/spellEngine.test
 */

import * as assert from 'assert';
import { SpellEngine } from '../../src/services/spellEngine';

suite('SpellEngine Test Suite', () => {
  let engine: SpellEngine;

  suiteSetup(async function () {
    // Increase timeout for first-time dictionary loading
    this.timeout(30000);
    engine = new SpellEngine();
    await engine.initialize();
  });

  suiteTeardown(() => {
    engine.dispose();
  });

  suite('Initialization', () => {
    test('should initialize without error', async () => {
      const testEngine = new SpellEngine();
      await assert.doesNotReject(async () => {
        await testEngine.initialize();
      });
      testEngine.dispose();
    });

    test('should throw if getSuggestions called before initialize', async () => {
      const testEngine = new SpellEngine();
      await assert.rejects(
        async () => {
          await testEngine.getSuggestions('hello');
        },
        {
          message: 'SpellEngine not initialized. Call initialize() first.',
        }
      );
    });
  });

  suite('getSuggestions', () => {
    test('should return suggestions for misspelled word', async function () {
      this.timeout(10000);
      const suggestions = await engine.getSuggestions('helo');
      assert.ok(suggestions.length > 0, 'Should return at least one suggestion');
      // 'hello' should be among the suggestions
      const hasHello = suggestions.some(
        (s) => s.toLowerCase() === 'hello'
      );
      assert.ok(hasHello, 'Should suggest "hello" for "helo"');
    });

    test('should return empty array for empty string', async () => {
      const suggestions = await engine.getSuggestions('');
      assert.strictEqual(suggestions.length, 0);
    });

    test('should return empty array for whitespace only', async () => {
      const suggestions = await engine.getSuggestions('   ');
      assert.strictEqual(suggestions.length, 0);
    });

    test('should respect maxResults parameter', async function () {
      this.timeout(10000);
      const suggestions = await engine.getSuggestions('helo', 3);
      assert.ok(
        suggestions.length <= 3,
        `Expected at most 3 suggestions, got ${suggestions.length}`
      );
    });

    test('should not include original word in suggestions', async function () {
      this.timeout(10000);
      const word = 'helo';
      const suggestions = await engine.getSuggestions(word);
      const hasOriginal = suggestions.some(
        (s) => s.toLowerCase() === word.toLowerCase()
      );
      assert.ok(!hasOriginal, 'Should not include original word in suggestions');
    });
  });

  suite('Caching', () => {
    test('should cache results', async function () {
      this.timeout(10000);
      // First call - populates cache
      const suggestions1 = await engine.getSuggestions('tset');
      const stats1 = engine.getCacheStats();

      // Second call - should use cache
      const suggestions2 = await engine.getSuggestions('tset');
      const stats2 = engine.getCacheStats();

      assert.deepStrictEqual(
        suggestions1,
        suggestions2,
        'Cached results should match'
      );
      assert.strictEqual(
        stats1.size,
        stats2.size,
        'Cache size should not change on cache hit'
      );
    });

    test('should return correct cache stats', () => {
      const stats = engine.getCacheStats();
      assert.ok(typeof stats.size === 'number');
      assert.ok(typeof stats.maxSize === 'number');
      assert.ok(stats.maxSize > 0);
    });

    test('should clear cache', async function () {
      this.timeout(10000);
      // Populate cache
      await engine.getSuggestions('cleartest');
      const statsBefore = engine.getCacheStats();
      assert.ok(statsBefore.size > 0, 'Cache should have entries');

      // Clear cache
      engine.clearCache();
      const statsAfter = engine.getCacheStats();
      assert.strictEqual(statsAfter.size, 0, 'Cache should be empty after clear');
    });
  });

  suite('isCorrect', () => {
    test('should return true for correctly spelled word', async function () {
      this.timeout(10000);
      const isCorrect = await engine.isCorrect('hello');
      assert.strictEqual(isCorrect, true, '"hello" should be correct');
    });

    test('should return false for misspelled word', async function () {
      this.timeout(10000);
      const isCorrect = await engine.isCorrect('helo');
      assert.strictEqual(isCorrect, false, '"helo" should be incorrect');
    });

    test('should return true for empty string', async () => {
      const isCorrect = await engine.isCorrect('');
      assert.strictEqual(isCorrect, true);
    });
  });

  suite('Configuration', () => {
    test('should update config', async function () {
      this.timeout(10000);
      const testEngine = new SpellEngine({ maxSuggestions: 5 });
      await testEngine.initialize();

      // Populate cache with initial config
      await testEngine.getSuggestions('configtest');
      const statsBefore = testEngine.getCacheStats();

      // Update config should clear cache
      testEngine.updateConfig({ language: 'en-GB' });
      const statsAfter = testEngine.getCacheStats();

      assert.strictEqual(
        statsAfter.size,
        0,
        'Cache should be cleared after config update'
      );
      testEngine.dispose();
    });

    test('should use custom maxCacheSize', () => {
      const customSize = 500;
      const testEngine = new SpellEngine({}, customSize);
      const stats = testEngine.getCacheStats();
      assert.strictEqual(stats.maxSize, customSize);
      testEngine.dispose();
    });
  });

  suite('Dispose', () => {
    test('should clear cache on dispose', async function () {
      this.timeout(10000);
      const testEngine = new SpellEngine();
      await testEngine.initialize();
      await testEngine.getSuggestions('disposetest');

      testEngine.dispose();
      const stats = testEngine.getCacheStats();
      assert.strictEqual(stats.size, 0, 'Cache should be empty after dispose');
    });

    test('should throw after dispose when calling getSuggestions', async () => {
      const testEngine = new SpellEngine();
      await testEngine.initialize();
      testEngine.dispose();

      await assert.rejects(
        async () => {
          await testEngine.getSuggestions('hello');
        },
        {
          message: 'SpellEngine not initialized. Call initialize() first.',
        }
      );
    });
  });
});
