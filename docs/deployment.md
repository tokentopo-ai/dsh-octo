# dsh profile 安装与迁移

dsh-octo 通过静态 bundle 向 profile 贡献：

- packaged `dsh-octo` skill provider；
- `codex` 与 `claude-code` product providers；
- `subagent_codex`、`subagent_claude_code`、`subagent_deepseek_v4_pro`、
  `subagent_deepseek_v4_flash` 四个固定工具。

bundle 不管理认证，也不执行任何编排阶段。

## 1. 前置检查

```bash
dsh --version
claude --version
codex --version
```

当前 package dependencies 固定为 `0.1.0-rc.6`；dsh 版本不一致时不要直接安装，应先更新
兼容矩阵并在隔离 profile 复测。

迁移已有 profile 前备份用户 patch：

```bash
cp "$HOME/.dsh/profiles/web/cordis.patch.yml" \
  "$HOME/.dsh/profiles/web/cordis.patch.yml.before-dsh-octo"
```

## 2. 安装 bundle

### tarball / registry

在仓库根生成并保留 tarball：

```bash
npm pack
dsh plugin --profile web add ./dsh-octo-0.1.0.tgz
```

发布到 registry 后可改为 `dsh plugin --profile web add dsh-octo@<version>`。

本地开发也必须安装 `npm pack` 生成的 tarball，不支持 `dsh plugin add .` 的 `link:`
形态。linked checkout 不会把 bundle dependencies 暴露给 profile 的 bare-module 解析，
而且会让 packaged skill 的资源根覆盖整个 checkout，包括不应进入 dsh 资源面的私有开发
文件。tarball/registry 安装只暴露 package allowlist。

profile 使用 `autoInstallPeers: false`；bundle 已把 `dsh-sdk-protocol` 声明为直接 dependency。
安装出现 peer warning 时继续做下面的 provider import 与实际启动验证，不能只看依赖命令
退出码。

## 3. 清理旧手工部署

安装命令只改变依赖和 bundle layer，不会自动编辑用户 patch。先查看组合树：

```bash
dsh --profile web --dump-config > /tmp/dsh-octo-web-config.yml
rg -n 'subagent_(codex|claude_code|deepseek_v4)' /tmp/dsh-octo-web-config.yml
```

若 profile 过去合并过旧补丁，从
`$HOME/.dsh/profiles/web/cordis.patch.yml` 删除以下旧 `insert` rows：

- `subagent-codex`
- `subagent-claude-code`
- `tool-subagent-codex`
- `tool-subagent-claude-code`
- `tool-subagent-deepseek-v4-pro`
- `tool-subagent-deepseek-v4-flash`

不要保留旧 rows 与 bundle rows 并存：Cordis patch insertion 不会按 id 自动去重。

重新 dump，确认上述四个 `toolName` 各出现一次，并来自 `# == dsh-octo` layer。

## 4. 验证 packaged skill 后移除旧链接

先启动 profile，在新会话确认：

1. skill 目录出现 `dsh-octo`；
2. `skill({ name: "dsh-octo" })` 可读正文和 `docs/`；
3. 四个 `subagent_*` 工具可见。

确认后再移除旧 dsh filesystem link：

```bash
if [ -L "$HOME/.dsh/skills/dsh-octo" ]; then
  rm "$HOME/.dsh/skills/dsh-octo"
fi
```

旧 user-dsh skill rank 高于 packaged skill；两者共存时目录只显示旧版本，而不是两份。
`~/.agents/skills/dsh-octo` 属于非 dsh 消费者，不要在这一步删除。

## 5. 运行时验证

从 profile 根验证 provider imports：

```bash
cd "$HOME/.dsh/profiles/web"
node --input-type=module -e \
  "await import('@deepseek-ai/dsh-subagent-codex'); await import('@deepseek-ai/dsh-subagent-claude-code'); console.log('provider imports: ok')"
```

重启 dsh 后可做不含敏感信息的最小委派测试。凭据由各 backend 原生管理；不要把值写入
patch、skill、prompt 或日志。

## 6. 回滚

```bash
dsh plugin --profile web remove dsh-octo
```

随后恢复备份的 profile patch；如需回到 filesystem skill，再重新建立旧链接。回滚前后
都用 `--dump-config` 确认没有重复 rows。
