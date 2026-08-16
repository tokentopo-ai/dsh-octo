import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

import { apply, inject, name } from '../index.js'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

async function registeredProvider() {
  let provider
  const ctx = {
    skills: {
      registerProvider(create) {
        provider = create({ signal: new AbortController().signal, invalidate() {} })
        return () => {}
      },
    },
  }
  apply(ctx)
  assert.ok(provider)
  return provider
}

test('exports a skills-only Cordis plugin', () => {
  assert.equal(name, 'dsh-octo-skill-provider')
  assert.deepEqual(inject, ['skills'])
})

test('registers one packaged dsh-octo skill', async () => {
  const provider = await registeredProvider()
  const candidates = await provider.list({})

  assert.equal(provider.name, 'dsh-octo')
  assert.equal(candidates.length, 1)
  assert.deepEqual(candidates[0].invocation, {
    modelInvocable: true,
    userInvocable: false,
  })
  assert.equal(candidates[0].source, 'bundled')
  assert.equal(candidates[0].rank, 600)
  assert.equal(candidates[0].resourceBase.kind, 'directory')
  assert.equal(resolve(candidates[0].resourceBase.path), root)
})

test('loads the skill body without YAML frontmatter', async () => {
  const provider = await registeredProvider()
  const [candidate] = await provider.list({})
  const skill = await provider.get(candidate, {})

  assert.ok(skill)
  assert.ok(skill.content.startsWith('# dsh-octo：多阶段复杂任务的外部 Agent 编排契约'))
  assert.doesNotMatch(skill.content, /^---$/m)
  assert.equal(skill.path, resolve(root, 'SKILL.md'))
  assert.equal(await provider.get({ name: 'other-skill' }, {}), undefined)
})

test('keeps provider metadata aligned with SKILL.md frontmatter', async () => {
  const provider = await registeredProvider()
  const [candidate] = await provider.list({})
  const markdown = await readFile(resolve(root, 'SKILL.md'), 'utf8')
  const nameMatch = /^name:\s*(.+)$/m.exec(markdown)
  const descriptionMatch = /^description:\s*(.+)$/m.exec(markdown)
  const invocationMatch = /^user-invocable:\s*(.+)$/m.exec(markdown)

  assert.equal(candidate.name, nameMatch?.[1])
  assert.equal(candidate.description, descriptionMatch?.[1])
  assert.equal(invocationMatch?.[1], 'false')
})
