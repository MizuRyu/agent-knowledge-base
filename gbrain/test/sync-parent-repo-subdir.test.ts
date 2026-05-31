import { describe, test, expect, afterEach } from 'bun:test';
import { execFileSync } from 'child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { buildSyncManifest } from '../src/core/sync.ts';
import {
  buildGitInvocation,
  buildScopedDiffArgs,
  isGitBackedPath,
} from '../src/commands/sync.ts';

let root: string | undefined;

afterEach(() => {
  if (root) rmSync(root, { recursive: true, force: true });
  root = undefined;
});

describe('sync source inside a parent Git repository', () => {
  test('accepts the source subdirectory and scopes commit diff to it', () => {
    root = mkdtempSync(join(tmpdir(), 'gbrain-parent-repo-'));
    const source = join(root, 'knowledge/work');
    mkdirSync(join(source, 'concepts'), { recursive: true });
    mkdirSync(join(root, 'docs'), { recursive: true });
    writeFileSync(join(source, 'concepts/a.md'), '# Concept A\n');
    writeFileSync(join(root, 'docs/outside.md'), '# Outside source\n');

    execFileSync('git', ['init', '-q', root]);
    execFileSync('git', ['-C', root, 'config', 'user.name', 'GBrain Test']);
    execFileSync('git', ['-C', root, 'config', 'user.email', 'gbrain@example.test']);
    execFileSync('git', ['-C', root, 'add', '.']);
    execFileSync('git', ['-C', root, 'commit', '-qm', 'initial']);

    const emptyTree = execFileSync(
      'git',
      ['-C', root, 'hash-object', '-t', 'tree', '--stdin'],
      { input: '', encoding: 'utf-8' },
    ).trim();
    const diff = execFileSync(
      'git',
      buildGitInvocation(source, buildScopedDiffArgs(`${emptyTree}..HEAD`)),
      { encoding: 'utf-8' },
    );

    expect(isGitBackedPath(source)).toBe(true);
    expect(buildSyncManifest(diff)).toEqual({
      added: ['concepts/a.md'],
      modified: [],
      deleted: [],
      renamed: [],
    });
  });
});
