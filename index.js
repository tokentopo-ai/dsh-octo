import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

const PROVIDER_NAME = 'dsh-octo'
const DESCRIPTION = '用于多阶段复杂任务（计划→编码→审核，按需实验）的外部异构 Agent 编排：当任务需要方案选型、多实现对比或独立评审时，主线 agent 按阶段调用 dsh 官方 subagent backend（subagent_claude_code / subagent_codex / subagent_deepseek_v4_pro / subagent_deepseek_v4_flash）协作，以产物文件交接。简单任务、单点修改、直接问答不使用本 skill。'
const SKILL_URL = new URL('./SKILL.md', import.meta.url)
const SKILL_PATH = fileURLToPath(SKILL_URL)
const RESOURCE_BASE = {
  kind: 'directory',
  path: fileURLToPath(new URL('./', import.meta.url)),
}
const INVOCATION = { modelInvocable: true, userInvocable: false }
const CANDIDATE = {
  name: 'dsh-octo',
  description: DESCRIPTION,
  invocation: INVOCATION,
  provider: PROVIDER_NAME,
  source: 'bundled',
  resourceBase: RESOURCE_BASE,
  rank: 600,
  locator: SKILL_URL,
  path: SKILL_PATH,
}

function stripFrontmatter(markdown) {
  const match = /^---\r?\n[\s\S]*?\r?\n---\r?\n/.exec(markdown)
  if (match === null) throw new Error('dsh-octo: SKILL.md is missing YAML frontmatter')
  return markdown.slice(match[0].length).replace(/^\r?\n/, '')
}

const provider = {
  name: PROVIDER_NAME,
  list: async () => [CANDIDATE],
  async get(candidate) {
    if (candidate.name !== CANDIDATE.name) return undefined
    return {
      name: CANDIDATE.name,
      description: CANDIDATE.description,
      invocation: CANDIDATE.invocation,
      provider: CANDIDATE.provider,
      source: CANDIDATE.source,
      resourceBase: RESOURCE_BASE,
      path: SKILL_PATH,
      content: stripFrontmatter(await readFile(SKILL_URL, 'utf8')),
    }
  },
}

export const name = 'dsh-octo-skill-provider'
export const inject = ['skills']

export function apply(ctx) {
  ctx.skills.registerProvider(() => provider)
}
