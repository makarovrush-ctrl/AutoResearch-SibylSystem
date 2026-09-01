# 玄学研究 Agent · 紫微斗数

独立的 Cursor Cloud Agent 仓库，专门用于玄学（紫微斗数）研究。**不接入 Sibyl autoResearch 流水线或 MCP**，仅通过 Cursor Skill 使用 [Renhuai123/ziwei-doushu](https://github.com/Renhuai123/ziwei-doushu) 排盘引擎。

## 仓库结构

| 路径 | 说明 |
|------|------|
| `.cursor/environment.json` | Cloud Agent 环境配置 |
| `.cursor/skills/ziwei-doushu/SKILL.md` | 紫微斗数研究 skill |
| `scripts/install.sh` | 克隆并安装 ziwei-doushu |
| `vendor/ziwei-doushu/` | 安装后生成的上游引擎（gitignore） |

## 快速开始

### 1. 克隆本仓库

```bash
git clone https://github.com/makarovrush-ctrl/xuanxue-research.git
cd xuanxue-research
```

### 2. 安装排盘引擎

```bash
bash scripts/install.sh
```

### 3. 在 Cursor 中启动 Cloud Agent

对本仓库启动 Cloud Agent。环境会自动运行 `install`，并加载 `ziwei-doushu` skill。

在 Agent 对话中可输入 `/ziwei-doushu`，或直接描述排盘需求，例如：

> 公历 1990 年 5 月 15 日 午时，男，帮我排盘并分析命宫与财帛宫。

## Agent 会做什么

1. 调用 `generateChart` 生成命盘
2. 查阅 `patterns.ts` 格局规则
3. 必要时检索古籍原文（骨髓赋、全书/全集）
4. 输出结构化解读

## 上游项目

- 排盘引擎：https://github.com/Renhuai123/ziwei-doushu
- 线上体验：https://metisziwei.com
- 体系：倪海夏《天纪》
- 许可：代码 MIT；样本数据需 attribution

## 与 Sibyl 的关系

本仓库**完全独立**于 [AutoResearch-SibylSystem](https://github.com/makarovrush-ctrl/AutoResearch-SibylSystem)。不依赖 `sibyl/orchestrate.py`、GPU 实验或文献 MCP。

## 发布到 GitHub（维护者）

若需重新推送或迁移：

```bash
bash scripts/publish-to-github.sh <github-owner>
```

默认 owner 为 `makarovrush-ctrl`。
