/**
 * Extension Integration Tests
 *
 * Tests for extension activation and command registration.
 *
 * @module test/suite/extension.test
 */

import * as assert from 'assert';
import * as vscode from 'vscode';

suite('Extension Test Suite', () => {
  vscode.window.showInformationMessage('Start all tests.');

  test('Extension should be present', () => {
    const extension = vscode.extensions.getExtension('laststance.complete');
    assert.ok(extension, 'Extension should be installed');
  });

  test('Extension should activate', async () => {
    const extension = vscode.extensions.getExtension('laststance.complete');
    assert.ok(extension, 'Extension should be installed');

    await extension.activate();
    assert.strictEqual(extension.isActive, true, 'Extension should be active');
  });

  test('Command should be registered', async () => {
    const commands = await vscode.commands.getCommands(true);
    assert.ok(
      commands.includes('complete.triggerCompletion'),
      'triggerCompletion command should be registered'
    );
  });

  test('Command should execute without error', async () => {
    // Open a new untitled document to have an active editor
    const document = await vscode.workspace.openTextDocument({
      content: 'Hello world',
      language: 'plaintext',
    });
    await vscode.window.showTextDocument(document);

    // Execute the command - should not throw
    await vscode.commands.executeCommand('complete.triggerCompletion');

    // Close the document
    await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
  });
});
