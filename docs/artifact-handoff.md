# 产物交接规则

异构 agent 不共享对话上下文，只通过目标项目根下的 `artifacts/` 交接。

## 1. 目录

```text
artifacts/
├── input/
├── plan/
├── impl/
├── review/
├── experiments/
└── logs/
```

## 2. 命名与所有权

文件名使用 `<阶段>-<序号>-<agent>.<ext>`：

| 产物 | 写入方 | 读取方 |
| --- | --- | --- |
| `input/task.md` | 主线 | 所有阶段 |
| `plan/plan-01-fable.md` | fable | 最终计划综合者 |
| `plan/plan-02..05-deepseek-v4-pro.md` | 四个独立计划 agent | 最终计划综合者 |
| `plan/plan-final.md` | deepseek-v4-flash | 编码、审核、实验分析 |
| `impl/impl-0<n>-deepseek-v4-pro.md` | 对应 worktree agent | 最终实现者 |
| `impl/impl-final-gpt-5.6-sol.md` | 最终实现者 | 审核者 |
| `review/review-gpt-5.6-sol.md` | 审核者 | 主线、用户 |
| `experiments/experiment-*.md` | 主线 | fable |

并行调用的 prompt 日志必须带序号，不能共享输出文件。

## 3. 最小读取

- 每个 agent 只读取任务输入、直接上一阶段产物和 prompt 点名的源码。
- 文件是交接真值；stdout 只作诊断。
- 读取/写入路径在 prompt 中显式给出，禁止自行遍历无关 artifacts。
- 涉敏输入只记录处理方法，不把原值复制到产物。

## 4. Git worktree

- 四个实现使用 sibling worktree `<basename>-dsh-octo-wt-01..04`，基于同一 commit。
- 每个实现 agent 只修改自己的 worktree，不提交，不触碰主工作树。
- 最终实现者从实现说明与各 worktree diff 选择方案，在主工作树落地。
- 审核结束后由主线按用户意愿保留或移除 worktree；清理动作写入审核记录。
