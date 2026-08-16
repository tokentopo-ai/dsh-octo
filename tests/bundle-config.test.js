import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'
import { parse } from 'yaml'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const expectedDependencies = {
  '@deepseek-ai/dsh-sdk-protocol': '0.1.0-rc.6',
  '@deepseek-ai/dsh-subagent-claude-code': '0.1.0-rc.6',
  '@deepseek-ai/dsh-subagent-codex': '0.1.0-rc.6',
  '@deepseek-ai/dsh-tool-subagent': '0.1.0-rc.6',
}

async function manifest() {
  return JSON.parse(await readFile(resolve(root, 'package.json'), 'utf8'))
}

async function rows() {
  const patches = parse(await readFile(resolve(root, 'cordis.patch.yml'), 'utf8'))
  assert.equal(patches.length, 1)
  return patches[0].insert
}

test('declares an installable dsh bundle with an explicit publish allowlist', async () => {
  const pkg = await manifest()
  assert.equal(pkg.name, 'dsh-octo')
  assert.equal(pkg.dsh.bundle.patch, './cordis.patch.yml')
  assert.equal(pkg.exports['./cordis.patch.yml'], './cordis.patch.yml')
  assert.equal(pkg.exports['./SKILL.md'], './SKILL.md')
  assert.deepEqual(pkg.dependencies, expectedDependencies)
  assert.deepEqual(pkg.files, [
    'index.js',
    'cordis.patch.yml',
    'SKILL.md',
    'assets/icon.png',
    'docs/',
    'README.md',
    'README_zh.md',
  ])
  assert.ok(!pkg.files.some(path => path.includes('local_docs')))
})

test('registers one skill provider, two product providers, and four tools', async () => {
  const entries = await rows()
  const byId = new Map(entries.map(entry => [entry.id, entry]))

  assert.equal(entries.length, 7)
  assert.equal(byId.get('dsh-octo-skill-provider')?.name, 'dsh-octo')
  assert.equal(byId.get('dsh-octo-subagent-codex')?.name, '@deepseek-ai/dsh-subagent-codex')
  assert.equal(byId.get('dsh-octo-subagent-claude-code')?.name, '@deepseek-ai/dsh-subagent-claude-code')

  const toolRows = entries.filter(entry => entry.name === '@deepseek-ai/dsh-tool-subagent')
  assert.deepEqual(toolRows.map(entry => entry.config.toolName).sort(), [
    'subagent_claude_code',
    'subagent_codex',
    'subagent_deepseek_v4_flash',
    'subagent_deepseek_v4_pro',
  ])
  assert.equal(byId.get('dsh-octo-tool-subagent-codex')?.config.enableRunInBackground, false)
  assert.equal(byId.get('dsh-octo-tool-subagent-claude-code')?.config.enableRunInBackground, false)
  assert.deepEqual(byId.get('dsh-octo-tool-subagent-deepseek-v4-pro')?.config.agentOptions, {
    provider: 'deepseek-official',
    model: 'deepseek-v4-pro',
  })
  assert.deepEqual(byId.get('dsh-octo-tool-subagent-deepseek-v4-flash')?.config.agentOptions, {
    provider: 'deepseek-official',
    model: 'deepseek-v4-flash',
  })
})

test('keeps orchestration logic out of the plugin layer', async () => {
  const source = await readFile(resolve(root, 'index.js'), 'utf8')
  const patch = await readFile(resolve(root, 'cordis.patch.yml'), 'utf8')
  assert.doesNotMatch(source, /subagents\.start|worktree|dsh_octo_run|workflow/i)
  assert.doesNotMatch(patch, /dsh_octo_run|workflow/i)
})

test('ships every relative runtime document named by SKILL.md', async () => {
  const markdown = await readFile(resolve(root, 'SKILL.md'), 'utf8')
  const paths = [...markdown.matchAll(/`(docs\/[a-z0-9-]+\.md)`/g)].map(match => match[1])
  assert.ok(paths.length >= 5)
  await Promise.all([...new Set(paths)].map(path => readFile(resolve(root, path), 'utf8')))
})
