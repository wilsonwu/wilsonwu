---
title: "让模型自己选模型：Embedding 驱动的 LLM 智能路由机制"
description: 
publishdate: 2026-05-26
attribution: "Wilson Wu"
tags: [azure,ai,embedding,gateway,llm,python,model,smart,semantic,router]
---

在多模型并存的 AI 架构中（如 GPT-4 / GPT-4o / 轻量模型 / 垂直模型等），一个核心问题是：

> **如何在不显式指定模型 ID 的情况下，让系统自动选择最合适的模型？**

本文介绍一种工程可落地的方案：

> **通过 Embedding 模型计算用户意图 → 在网关层进行语义匹配 → 动态路由到最合适的上游模型服务**

我们将基于：

* Embedding 模型：Azure OpenAI `text-embedding-3-small`
* 网关：Envoy
* 核心机制：向量相似度打分 + 策略路由

## 问题背景与动机

在真实生产环境中，大模型调用通常面临几个挑战：

### 1. 成本与性能权衡

| 模型类型               | 优点     | 缺点        |
| ------------------ | ------ | --------- |
| 大模型（如 GPT-4）       | 能力强    | 成本高 / 延迟高 |
| 小模型（如 GPT-4o-mini） | 快 / 便宜 | 能力有限      |
| 专用模型               | 精准     | 泛化弱       |

不同请求应该走不同模型，而不是“一刀切”。

### 2. 传统做法的局限

常见策略：

* 手动指定 model_id ❌（不智能）
* 基于规则（if/else）❌（不可扩展）
* 基于关键词匹配 ❌（语义不鲁棒）

### 3. 理想目标

我们希望：

> 用户只输入 prompt，系统自动理解“意图”，并选择最优模型

这正是 Embedding 可以发挥作用的地方。

## 核心原理：Embedding 驱动的语义路由

### 1. Embedding 本质

Embedding 模型（如 `text-embedding-3-small`）可以将文本映射为高维向量：

```
"写一段 Python 排序代码"
→ [0.012, -0.98, ..., 0.33]  (1536维向量)
```

语义相似的文本，其向量距离更近。

### 2. 路由思路

核心逻辑可以抽象为：

```
用户请求 → Embedding → 与“意图模板库”计算相似度 → 选择最佳匹配 → 路由模型
```

### 3. 意图模板（Intent Prototypes）

我们预先定义一组“意图向量”：

| 意图类型 | 示例文本                              | 目标模型        |
| ---- | --------------------------------- | ----------- |
| 代码生成 | "write code", "generate function" | GPT-4       |
| 简单问答 | "what is", "define"               | GPT-4o-mini |
| 翻译   | "translate this"                  | 轻量模型        |
| 长文生成 | "write blog"                      | GPT-4       |

这些文本会提前计算 embedding 并缓存。

### 4. 相似度计算

常用方法：

* Cosine Similarity（推荐）

```
similarity = cosine(query_embedding, intent_embedding)
```

选择最高分：

```
argmax(similarity_i)
```

## 系统架构设计

整体架构如下：

```
                ┌──────────────┐
                │   Client     │
                └──────┬───────┘
                       │
               ┌───────▼────────┐
               │    Envoy 网关   │
               │   (智能路由层)   │
               └───────┬────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
 ┌──────▼─────┐ ┌──────▼─────┐ ┌──────▼─────┐
 │ GPT-4      │ │ GPT-4o-mini│ │ 专用模型    │
 └────────────┘ └────────────┘ └────────────┘
```

## 实现逻辑拆解

### 1. 请求流程

#### Step 1：获取用户请求

```json
{
  "input": "帮我写一段 Go 的 HTTP server 示例"
}
```

#### Step 2：调用 Embedding API

使用 Azure OpenAI：

```http
POST https://{endpoint}/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-02-15-preview
```

请求体：

```json
{
  "input": "帮我写一段 Go 的 HTTP server 示例"
}
```

#### Step 3：计算相似度

伪代码：

```python
def route(query_embedding):
    best_score = -1
    best_model = None

    for intent in intents:
        score = cosine_similarity(query_embedding, intent.embedding)
        if score > best_score:
            best_score = score
            best_model = intent.model

    return best_model
```

#### Step 4：Envoy 动态路由

将结果写入 Header：

```
x-llm-route: gpt-4
```

Envoy 根据 Header 路由：

```yaml
routes:
- match:
    prefix: "/v1/chat"
    headers:
      - name: x-llm-route
        exact_match: gpt-4
  route:
    cluster: gpt4_service
```

## Envoy 网关实现方式

Envoy 本身不直接支持向量计算，因此需要扩展：

### 方案 1：External Processing（推荐）

Envoy 调用外部服务（ext_proc）：

```
Envoy → ext_proc 服务 → 返回路由决策 → Envoy 转发
```

ext_proc 负责：

* 调用 embedding
* 计算相似度
* 返回 header

### 方案 2：WASM 插件

在 Envoy 内嵌逻辑：

* 优点：低延迟
* 缺点：开发复杂（Rust/CPP）

### 方案 3：Sidecar Router（简单）

```
Client → Router Service → Envoy → Model
```

Router 服务负责所有智能逻辑。

## 优化策略

### 1. 向量缓存

避免重复调用 embedding：

```python
cache[input_hash] = embedding
```

### 2. 意图分层

避免单层分类过粗：

```
一级：代码 / 问答 / 写作
二级：语言 / 长度 / 难度
```

### 3. 阈值控制

```python
if best_score < threshold:
    fallback_model = "gpt-4"
```

防止误判。

### 4. 多模型融合（Ensemble）

可扩展为：

* Top-K 模型候选
* A/B 测试
* 加权路由

### 5. 成本感知路由

结合：

* token 预算
* 用户等级
* SLA

做策略增强：

```python
if user == "free":
    prefer_small_model()
```

## 优势分析

### 相比规则路由

| 维度   | Embedding 路由 |
| ---- | ------------ |
| 语义理解 | 强            |
| 可扩展性 | 高            |
| 维护成本 | 低            |

### 相比手动指定模型

* 用户体验更好（无需关心模型）
* 自动最优成本
* 支持动态策略

## 落地建议

### 1. 初始阶段

* 5~10 个意图模板即可
* 手动标注 + 调优

### 2. 数据驱动优化

记录：

* 用户请求
* 路由结果
* 用户反馈

持续优化 intent embedding。

### 3. 与 LLM Router 结合

未来可以升级为：

> 用小模型 + embedding 混合决策（Hybrid Router）

## 总结

本文方案的本质是：

> **用 Embedding 替代规则，用向量相似度驱动模型选择**

关键收益：

* 降低成本（智能选择轻量模型）
* 提升效果（复杂任务走强模型）
* 架构解耦（路由逻辑与模型解耦）

在多模型时代，这种“语义驱动的网关”会成为标准架构组件。
