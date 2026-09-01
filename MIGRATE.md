# 迁移为独立 GitHub 仓库

Cloud Agent token 无法代你创建新仓库，请在本机执行以下步骤（约 1 分钟）。

## 步骤 1：在 GitHub 创建空仓库

打开：https://github.com/new

- **Repository name**: `xuanxue-research`
- **Owner**: `makarovrush-ctrl`（或你的个人账号）
- **不要**勾选 "Add a README"（保持空仓库）
- 点击 Create repository

## 步骤 2：推送代码

在终端运行（把 `makarovrush-ctrl` 换成你的 owner）：

```bash
git clone --branch xuanxue-research-standalone --single-branch \
  https://github.com/makarovrush-ctrl/AutoResearch-SibylSystem.git xuanxue-research

cd xuanxue-research
git remote remove origin
git remote add origin https://github.com/makarovrush-ctrl/xuanxue-research.git
git branch -M main
git push -u origin main
```

## 步骤 3：在 Cursor 中使用

1. 打开新仓库 `makarovrush-ctrl/xuanxue-research`
2. 启动 Cloud Agent（会自动运行 `scripts/install.sh`）
3. 对话中使用 `/ziwei-doushu` 或直接描述排盘需求

## 可选：删除 Sibyl 中的临时分支

独立仓库推送成功后，可删除 AutoResearch-SibylSystem 上的临时分支：

- `xuanxue-research-standalone`
- `cursor/xuanxue-ziwei-skill-93f0`（已关闭 PR #1）

```bash
git push origin --delete xuanxue-research-standalone
git push origin --delete cursor/xuanxue-ziwei-skill-93f0
```

## 一键脚本（仓库已创建后）

```bash
bash scripts/publish-to-github.sh makarovrush-ctrl
```

需在已 clone 的本仓库根目录执行，且 GitHub 空仓库已存在。
