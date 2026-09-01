# 玄学研究 Agent · 紫微斗数

独立的 Cursor Cloud Agent 项目，专门用于玄学（紫微斗数）研究。**不接入 Sibyl autoResearch 流水线或 MCP**，仅通过 Cursor Skill 使用 [Renhuai123/ziwei-doushu](https://github.com/Renhuai123/ziwei-doushu) 排盘引擎。

## 包含内容

| 路径 | 说明 |
|------|------|
| `.cursor/environment.json` | Cloud Agent 环境配置 |
| `.cursor/skills/ziwei-doushu/SKILL.md` | 紫微斗数研究 skill |
| `scripts/install.sh` | 克隆并安装 ziwei-doushu |
| `vendor/ziwei-doushu/` | 安装后生成的上游引擎（gitignore） |

## 使用方式

### 作为独立仓库（推荐）

将整个 `xuanxue-research/` 目录推送到新 GitHub 仓库，然后在 Cursor 中对该仓库启动 Cloud Agent。Agent 会自动加载 `ziwei-doushu` skill。

### 在本 monorepo 内

Skill 位于嵌套目录 `xuanxue-research/.cursor/skills/`，Cursor 会在处理该目录下文件时自动发现。在 Agent 对话中可显式调用：

```
/ziwei-doushu
```

或说明：「用 ziwei-doushu skill 帮我排盘」。

### 本地准备

```bash
cd xuanxue-research
bash scripts/install.sh
```

## 首次对话示例

> 公历 1990 年 5 月 15 日 午时，男，帮我排盘并分析命宫与财帛宫。

Agent 将：

1. 调用 `generateChart` 生成命盘
2. 查阅 `patterns.ts` 格局规则
3. 必要时检索古籍原文
4. 输出结构化解读

## 上游项目

- 仓库：https://github.com/Renhuai123/ziwei-doushu
- 线上体验：https://metisziwei.com
- 体系：倪海夏《天纪》
- 许可：代码 MIT；样本数据需 attribution

## 与 Sibyl 的关系

此 agent **独立于** AutoResearch-SibylSystem 的 19 阶段研究流水线。不依赖 `sibyl/orchestrate.py`、GPU 实验或文献 MCP。仅把 ziwei-doushu 作为玄学研究的工具 skill 接入 Cursor Agent。
