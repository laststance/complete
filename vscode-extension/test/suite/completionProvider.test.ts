/**
 * CompletionProvider Integration Tests
 *
 * Tests for the inline completion provider functionality.
 *
 * @module test/suite/completionProvider.test
 */

import * as assert from 'assert';
import * as vscode from 'vscode';
import { SpellEngine } from '../../src/services/spellEngine';
import {
  SpellCompletionProvider,
  createCompletionProviderRegistration,
} from '../../src/providers/completionProvider';

suite('CompletionProvider Test Suite', () => {
  let engine: SpellEngine;
  let provider: SpellCompletionProvider;

  suiteSetup(async function () {
    this.timeout(30000);
    engine = new SpellEngine();
    await engine.initialize();
    provider = new SpellCompletionProvider(engine);
  });

  suiteTeardown(() => {
    engine.dispose();
  });

  suite('SpellCompletionProvider Configuration', () => {
    test('should create provider with default config', () => {
      const testProvider = new SpellCompletionProvider(engine);
      assert.ok(testProvider, 'Provider should be created');
    });

    test('should accept custom configuration', () => {
      const customProvider = new SpellCompletionProvider(engine, {
        maxSuggestions: 5,
      });
      assert.ok(customProvider, 'Provider with custom config should be created');
    });

    test('should update configuration', () => {
      const testProvider = new SpellCompletionProvider(engine);
      testProvider.updateConfig({ maxSuggestions: 15 });
      // Config update should not throw
      assert.ok(true, 'Config update should succeed');
    });
  });

  suite('provideCompletionItems', () => {
    let testDocument: vscode.TextDocument;

    suiteSetup(async function () {
      this.timeout(10000);
      // Create a test document with misspelled words
      testDocument = await vscode.workspace.openTextDocument({
        content: 'The quik brown fox jumps over the lasy dog',
        language: 'plaintext',
      });
    });

    suiteTeardown(async () => {
      await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
    });

    test('should return completion items for misspelled word', async function () {
      this.timeout(10000);

      // Position cursor on "quik" (position 6 is in the middle of "quik")
      const position = new vscode.Position(0, 6);

      // Create a cancellation token source
      const tokenSource = new vscode.CancellationTokenSource();

      // Get completion items
      const items = await provider.provideCompletionItems(
        testDocument,
        position,
        tokenSource.token
      );

      assert.ok(Array.isArray(items), 'Should return an array');
      assert.ok(items.length > 0, 'Should return suggestions');

      // Verify "quick" is in suggestions
      const hasQuick = items.some((item) =>
        item.label.toString().toLowerCase() === 'quick'
      );
      assert.ok(hasQuick, 'Should suggest "quick"');

      tokenSource.dispose();
    });

    test('should return empty array for very short words', async function () {
      this.timeout(5000);

      // Create document with short word
      const doc = await vscode.workspace.openTextDocument({
        content: 'I am a test',
        language: 'plaintext',
      });

      // Position on "I" (single character)
      const position = new vscode.Position(0, 0);
      const tokenSource = new vscode.CancellationTokenSource();

      const items = await provider.provideCompletionItems(
        doc,
        position,
        tokenSource.token
      );

      assert.strictEqual(items.length, 0, 'Should return empty for short words');

      tokenSource.dispose();
      await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
    });

    test('should return empty array for whitespace position', async function () {
      this.timeout(5000);

      // Position on whitespace (between words)
      const doc = await vscode.workspace.openTextDocument({
        content: 'hello   world',
        language: 'plaintext',
      });

      // Position in the middle of whitespace
      const position = new vscode.Position(0, 7);
      const tokenSource = new vscode.CancellationTokenSource();

      const items = await provider.provideCompletionItems(
        doc,
        position,
        tokenSource.token
      );

      assert.strictEqual(items.length, 0, 'Should return empty for whitespace');

      tokenSource.dispose();
      await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
    });

    test('should respect cancellation token', async function () {
      this.timeout(5000);

      const position = new vscode.Position(0, 6);
      const tokenSource = new vscode.CancellationTokenSource();

      // Cancel immediately
      tokenSource.cancel();

      const items = await provider.provideCompletionItems(
        testDocument,
        position,
        tokenSource.token
      );

      assert.strictEqual(items.length, 0, 'Should return empty when cancelled');

      tokenSource.dispose();
    });

    test('completion items should have correct properties', async function () {
      this.timeout(10000);

      const position = new vscode.Position(0, 6);
      const tokenSource = new vscode.CancellationTokenSource();

      const items = await provider.provideCompletionItems(
        testDocument,
        position,
        tokenSource.token
      );

      assert.ok(items.length > 0, 'Should have items');

      const firstItem = items[0];
      assert.ok(firstItem.label, 'Item should have label');
      assert.strictEqual(
        firstItem.kind,
        vscode.CompletionItemKind.Text,
        'Item kind should be Text'
      );
      assert.ok(firstItem.sortText, 'Item should have sortText');
      assert.ok(firstItem.range, 'Item should have range');
      assert.strictEqual(firstItem.detail, 'Spell suggestion', 'Item should have detail');

      tokenSource.dispose();
    });

    test('sortText should maintain suggestion order', async function () {
      this.timeout(10000);

      const position = new vscode.Position(0, 6);
      const tokenSource = new vscode.CancellationTokenSource();

      const items = await provider.provideCompletionItems(
        testDocument,
        position,
        tokenSource.token
      );

      assert.ok(items.length >= 2, 'Should have at least 2 items');

      // Check sortText is properly padded and ordered
      const sortTexts = items.map((item) => item.sortText);
      for (let i = 0; i < sortTexts.length - 1; i++) {
        assert.ok(
          sortTexts[i]! < sortTexts[i + 1]!,
          `sortText[${i}] should be less than sortText[${i + 1}]`
        );
      }

      tokenSource.dispose();
    });
  });

  suite('createCompletionProviderRegistration', () => {
    test('should create disposable registration', () => {
      const testProvider = new SpellCompletionProvider(engine);
      const registration = createCompletionProviderRegistration(testProvider);

      assert.ok(registration, 'Registration should be created');
      assert.ok(
        typeof registration.dispose === 'function',
        'Registration should be disposable'
      );

      // Clean up
      registration.dispose();
    });

    test('should accept trigger characters', () => {
      const testProvider = new SpellCompletionProvider(engine);
      const registration = createCompletionProviderRegistration(testProvider, ['.', ' ']);

      assert.ok(registration, 'Registration with triggers should be created');

      // Clean up
      registration.dispose();
    });
  });
});
