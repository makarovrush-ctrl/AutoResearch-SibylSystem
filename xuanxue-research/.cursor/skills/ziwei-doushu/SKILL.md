---
name: ziwei-doushu
description: 紫微斗数排盘与解读研究。使用 Renhuai123/ziwei-doushu 开源引擎（倪海夏《天纪》体系）进行命盘生成、格局判定、古籍检索与玄学分析。在用户讨论紫微斗数、命盘、四化、格局、合盘、玄学命理时使用。
icon: book-open
color: purple
---

# 紫微斗数 · ziwei-doushu

基于 [Renhuai123/ziwei-doushu](https://github.com/Renhuai123/ziwei-doushu) 开源排盘引擎，遵循**倪海夏《天纪》**正统体系（纯飞星派已下线）。

## 引擎位置

安装后位于 `vendor/ziwei-doushu/`。若缺失，运行：

```bash
bash scripts/install.sh
```

## 何时使用

- 根据出生年月日时排紫微命盘
- 查询十四主星、十二宫位、四化（禄权科忌）
- 判定经典格局（`lib/ziwei/patterns.ts`，1100+ 行规则）
- 合盘分析（`lib/ziwei/heming-knowledge.ts`）
- 查阅古籍原文（骨髓赋、紫微斗数全书/全集）
- 玄学研究、命理解读、样本数据分析

## 排盘 API

核心入口：`lib/ziwei/algorithm.ts` → `generateChart(birthInfo)`

```typescript
import { generateChart } from './lib/ziwei/algorithm';

const chart = generateChart({
  year: 1990,
  month: 5,
  day: 15,
  hour: 6,        // 时辰地支索引：0=子, 1=丑, … 11=亥
  gender: 'male', // 'male' | 'female'
  city: '北京',    // 可选，用于真太阳时
});
```

返回 `ZiweiChart`：十二宫、大限、命宫/身宫、五行局、紫微星位置等。类型定义见 `lib/ziwei/types.ts`。

### 时辰对照

| 地支 | 时辰 | hour 值 |
|------|------|---------|
| 子 | 23:00–01:00 | 0 |
| 丑 | 01:00–03:00 | 1 |
| 寅 | 03:00–05:00 | 2 |
| 卯 | 05:00–07:00 | 3 |
| 辰 | 07:00–09:00 | 4 |
| 巳 | 09:00–11:00 | 5 |
| 午 | 11:00–13:00 | 6 |
| 未 | 13:00–15:00 | 7 |
| 申 | 15:00–17:00 | 8 |
| 酉 | 17:00–19:00 | 9 |
| 戌 | 19:00–21:00 | 10 |
| 亥 | 21:00–23:00 | 11 |

出生时间不确定时，先向用户确认公历/农历、是否用真太阳时，再排盘。

## 知识库文件

| 路径 | 用途 |
|------|------|
| `lib/ziwei/algorithm.ts` | 完整排盘流程 |
| `lib/ziwei/sihua.ts` | 四化飞星（天干四化表） |
| `lib/ziwei/patterns.ts` | 格局判定规则库 |
| `lib/ziwei/heming-knowledge.ts` | 合盘方法论 |
| `lib/ziwei/constants.ts` | 天干地支、星曜常量 |
| `lib/ziwei/cities.ts` | 中国城市经纬度（真太阳时） |
| `lib/classics/gusuifu.ts` | 骨髓赋 |
| `lib/classics/quanji.ts` | 紫微斗数全集 |
| `lib/classics/quanshu.ts` | 紫微斗数全书 |
| `lib/seo/` | 十四主星 × 十二宫位知识图谱 |

## 快速排盘脚本

在 `vendor/ziwei-doushu` 目录下用 Node 执行：

```bash
cd vendor/ziwei-doushu
npx tsx -e "
import { generateChart } from './lib/ziwei/algorithm';
const c = generateChart({ year: 1990, month: 5, day: 15, hour: 6, gender: 'male' });
console.log(JSON.stringify(c, null, 2));
"
```

若 `tsx` 不可用，先 `npm install -D tsx`，或写临时 `.ts` 文件再运行。

## 研究流程

1. **确认输入**：公历生日、时辰、性别；必要时查 `cities.ts` 做真太阳时校正。
2. **生成命盘**：调用 `generateChart`，保存 JSON 到 `charts/` 便于对比。
3. **格局分析**：阅读 `patterns.ts` 中匹配规则，引用格局名称与判定逻辑。
4. **古籍佐证**：在 `lib/classics/` 检索相关歌诀或原文。
5. **综合解读**：结合命宫、身宫、大限、四化给出结构化分析；区分「排盘事实」与「解读推断」。
6. **合盘**（若需要）：参考 `heming-knowledge.ts` 的双盘比对逻辑。

## 样本数据集（可选）

仓库 Releases 提供 51.8 万条命盘样本（v3.0），可用于 RAG、微调或统计研究：

https://github.com/Renhuai123/ziwei-doushu/releases/tag/v3.0-samples

商用需保留 attribution（见上游 README）。

## 边界与限制

- 开源版**不含** AI 解读 prompt 与后端 API；解读由 agent 基于知识库自行完成。
- 四化按倪师体系**固定不动**（非飞星派宫干自化）。
- 不做医疗、投资等具体决策建议；命理分析仅供研究与文化探讨。
- 引用格局或古籍时注明出处（patterns.ts 规则名、classic 文件名）。

## 输出格式建议

```markdown
## 命盘概要
- 农历：…
- 五行局：…
- 命宫：… / 身宫：…

## 重点宫位
…

## 格局
- [格局名]：判定依据 …

## 大限流年
…

## 古籍参考
…

## 研究备注
（待验证假设、需补充信息）
```
