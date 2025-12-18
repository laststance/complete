/**
 * QuickPickProvider Integration Tests
 *
 * Tests for the QuickPick completion workflow.
 *
 * @module test/suite/quickPickProvider.test
 */

import * as assert from 'assert';
import * as vscode from 'vscode';
import { SpellEngine } from '../../src/services/spellEngine';
import { QuickPickProvider } from '../../src/providers/quickPickProvider';
import {
  getWordAtCursor,
  replaceWordAtCursor,
  hasWordAtCursor,
  getWordAtCursorWithContext,
} from '../../src/services/wordExtractor';

suite('QuickPickProvider Test Suite', () => {
  let engine: SpellEngine;
  let provider: QuickPickProvider;

  suiteSetup(async function () {
    this.timeout(30000);
    engine = new SpellEngine();
    await engine.initialize();
    provider = new QuickPickProvider(engine);
  });

  suiteTeardown(() => {
    engine.dispose();
  });

  suite('QuickPickProvider Configuration', () => {
    test('should create provider with default config', () => {
      const testProvider = new QuickPickProvider(engine);
      assert.ok(testProvider, 'Provider should be created');
    });

    test('should accept custom configuration', () => {
      const customProvider = new QuickPickProvider(engine, {
        title: 'Custom Title',
        placeholderTemplate: 'Custom: {word}',
      });
      assert.ok(customProvider, 'Provider with custom config should be created');
    });

    test('should update configuration', () => {
      const testProvider = new QuickPickProvider(engine);
      testProvider.updateConfig({ title: 'Updated Title' });
      // Config update should not throw
      assert.ok(true, 'Config update should succeed');
    });
  });
});

suite('WordExtractor Test Suite', () => {
  let testDocument: vscode.TextDocument;
  let testEditor: vscode.TextEditor;

  suiteSetup(async function () {
    this.timeout(10000);
    // Create a test document with clear whitespace regions
    // Line 0: "hello world test"
    // Line 1: "   " (only spaces - for whitespace testing)
    testDocument = await vscode.workspace.openTextDocument({
      content: 'hello world test\n   ',
      language: 'plaintext',
    });
    testEditor = await vscode.window.showTextDocument(testDocument);
  });

  suiteTeardown(async () => {
    // Close the test document
    await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
  });

  suite('getWordAtCursor', () => {
    test('should return word when cursor is on a word', async () => {
      // Position cursor on "hello"
      const position = new vscode.Position(0, 2);
      testEditor.selection = new vscode.Selection(position, position);

      const wordInfo = getWordAtCursor(testEditor);
      assert.ok(wordInfo, 'Should return word info');
      assert.strictEqual(wordInfo?.word, 'hello', 'Should return "hello"');
    });

    test('should return word when cursor is at word boundary', async () => {
      // Position cursor at start of "world"
      const position = new vscode.Position(0, 6);
      testEditor.selection = new vscode.Selection(position, position);

      const wordInfo = getWordAtCursor(testEditor);
      assert.ok(wordInfo, 'Should return word info');
      assert.strictEqual(wordInfo?.word, 'world', 'Should return "world"');
    });

    test('should return null when cursor is on whitespace-only line', async () => {
      // Position cursor on line with only spaces (line 1)
      const position = new vscode.Position(1, 1);
      testEditor.selection = new vscode.Selection(position, position);

      const wordInfo = getWordAtCursor(testEditor);
      assert.strictEqual(wordInfo, null, 'Should return null for whitespace-only line');
    });
  });

  suite('hasWordAtCursor', () => {
    test('should return true when cursor is on a word', async () => {
      const position = new vscode.Position(0, 2);
      testEditor.selection = new vscode.Selection(position, position);

      const result = hasWordAtCursor(testEditor);
      assert.strictEqual(result, true, 'Should return true for word');
    });

    test('should return false when cursor is on whitespace-only line', async () => {
      // Position cursor on line with only spaces (line 1)
      const position = new vscode.Position(1, 1);
      testEditor.selection = new vscode.Selection(position, position);

      const result = hasWordAtCursor(testEditor);
      assert.strictEqual(result, false, 'Should return false for whitespace-only line');
    });
  });

  suite('getWordAtCursorWithContext', () => {
    test('should return word with line context', async () => {
      const position = new vscode.Position(0, 8);
      testEditor.selection = new vscode.Selection(position, position);

      const result = getWordAtCursorWithContext(testEditor);
      assert.ok(result, 'Should return result');
      assert.strictEqual(result?.word, 'world', 'Should return "world"');
      assert.strictEqual(result?.lineNumber, 0, 'Should return line 0');
      assert.strictEqual(
        result?.lineText,
        'hello world test',
        'Should return full line text'
      );
    });
  });

  suite('replaceWordAtCursor', () => {
    test('should replace word at specified range', async () => {
      // Create a new document for replacement test
      const doc = await vscode.workspace.openTextDocument({
        content: 'helo world',
        language: 'plaintext',
      });
      const editor = await vscode.window.showTextDocument(doc);

      // Position cursor on "helo"
      const position = new vscode.Position(0, 2);
      editor.selection = new vscode.Selection(position, position);

      const wordInfo = getWordAtCursor(editor);
      assert.ok(wordInfo, 'Should find word');

      const success = await replaceWordAtCursor(editor, wordInfo!.range, 'hello');
      assert.strictEqual(success, true, 'Replace should succeed');

      // Verify the text was replaced
      const newText = doc.getText();
      assert.strictEqual(newText, 'hello world', 'Text should be replaced');

      // Cleanup
      await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
    });
  });
});

suite('Integration: End-to-End Workflow', () => {
  let engine: SpellEngine;

  suiteSetup(async function () {
    this.timeout(30000);
    engine = new SpellEngine();
    await engine.initialize();
  });

  suiteTeardown(() => {
    engine.dispose();
  });

  test('should complete full workflow: extract word, get suggestions, replace', async function () {
    this.timeout(15000);

    // Create test document with misspelled word
    const doc = await vscode.workspace.openTextDocument({
      content: 'The quik brown fox',
      language: 'plaintext',
    });
    const editor = await vscode.window.showTextDocument(doc);

    // Position cursor on "quik"
    const position = new vscode.Position(0, 6);
    editor.selection = new vscode.Selection(position, position);

    // Step 1: Extract word
    const wordInfo = getWordAtCursor(editor);
    assert.ok(wordInfo, 'Should extract word');
    assert.strictEqual(wordInfo?.word, 'quik', 'Should extract "quik"');

    // Step 2: Get suggestions
    const suggestions = await engine.getSuggestions(wordInfo!.word);
    assert.ok(suggestions.length > 0, 'Should get suggestions');

    // Verify "quick" is in suggestions
    const hasQuick = suggestions.some((s) => s.toLowerCase() === 'quick');
    assert.ok(hasQuick, 'Should suggest "quick"');

    // Step 3: Replace word (simulating user selection)
    const replacement = suggestions.find((s) => s.toLowerCase() === 'quick') ?? 'quick';
    const success = await replaceWordAtCursor(editor, wordInfo!.range, replacement);
    assert.strictEqual(success, true, 'Replace should succeed');

    // Verify final text
    const finalText = doc.getText();
    assert.ok(
      finalText.includes('quick'),
      'Document should contain corrected word'
    );

    // Cleanup
    await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
  });
});
