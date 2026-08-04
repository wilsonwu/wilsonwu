---
title: "在 vLLM Semantic Router 中使用 Microsoft Foundry 远程 Embedding 推理"
description: 
publishdate: 2026-08-03
attribution: "Wilson Wu"
tags: [azure,ai,vllm,vsr,vllm-sr,semantic-router,embedding,llm,remote]
---

## 1. 引言

在 vLLM Semantic Router 的设计中，Embedding 推理是驱动语义路由的核心信号之一。

官方教程已经演示了如何使用**远程 Embedding 推理提供商（Remote Embedding Providers）**替代本地 Embedding 推理服务：

👉 [https://vllm-sr.ai/docs/tutorials/global/remote-embeddings/](https://vllm-sr.ai/docs/tutorials/global/remote-embeddings/)

然而，在实际生产环境中，一个更为关键的问题随之而来：

> 如何使用企业级、可扩展的 Embedding 推理服务来支持语义路由？

本文基于官方教程中的场景，并结合 **Microsoft Foundry Embedding 模型**，演示如何构建一个具备以下特性的智能路由系统：

- 无需 GPU
- 无需在本地部署 Embedding 模型
- 生产就绪

## 2. 回顾：远程 Embedding 推理提供商

在 vLLM Semantic Router 中，路由器运行在 CPU 上，不依赖 GPU 推理能力。

通过远程 Embedding 推理提供商：

```text
路由器 → 远程 Embedding 推理 API → 向量
```

我们可以：

- 将嵌入计算完全卸载到云服务
- 统一多模型的语义能力
- 解耦路由与推理

## 3. 教程场景（沿用官方测试场景）

在官方教程中，核心流程如下：

![远程嵌入流程](1-remote-embeddings-flow.png)

### 第 1 步：定义语义路由

```yaml
routing:
  decisions:
    - name: math
      when:
        semantic_similarity:
          text: "math question"
          threshold: 0.8

    - name: general
```

### 第 2 步：发送请求

```bash
curl http://localhost:8888/v1/chat/completions \
  -d '{
    "model": "MoM",
    "messages": [{"role": "user", "content": "What is 1+1?"}]
  }'
```

路由器将执行以下操作：

1. 生成嵌入向量
2. 执行语义匹配
3. 选择目标模型

## 4. 第 0 步：在 Microsoft Foundry 中创建 Embedding 模型

在与 vLLM Semantic Router 集成之前，我们首先需要在 Microsoft Foundry 中部署一个 Embedding 模型。

### 4.1 创建 Foundry 项目

1. 前往 **Microsoft Foundry 门户**
2. 创建新项目（或选择现有项目）
3. 确保该项目已关联 Azure 订阅

### 4.2 部署嵌入模型

在模型目录中：

1. 搜索 **Embedding 模型**
2. 选择受支持的模型（例如 `text-embedding-3-small`）
3. 单击 **Deploy（部署）**

部署完成后，你将获得：

- Endpoint URL
- API Key
- Model Name

示例：

```text
Endpoint: https://<your-foundry-resource>.inference.ai.azure.com
Model: text-embedding-3-small
API Key: ******
```

### 4.3 验证 Embedding 推理 API

你可以直接测试该终结点：

```bash
curl https://<your-foundry-endpoint>/v1/embeddings \
  -H "api-key: <your-api-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Hello world"
  }'
```

如果调用成功，你将收到包含向量的响应。

## 5. 升级：使用 Microsoft Foundry 替代本地 Embedding 模型

现在，我们将教程中的 Embedding 推理提供商替换为：

> ✅ Microsoft Foundry Embedding 模型

![Microsoft Foundry Embedding 模型](2-microsoft-foundry-embedding-model.png)

## 6. 为什么选择 Microsoft Foundry Embedding 模型

Microsoft Foundry 提供：

- 高质量 Embedding 模型（更强的语义理解能力）
- 托管 API（无需自行部署）
- 全球可用性与企业级 SLA
- 与 Azure AI 生态系统无缝集成

更重要的是：

> 它可以直接充当 Semantic Router 的“语义大脑”

## 7. 集成：将 Microsoft Foundry 用作远程 Embedding 推理提供商

### 7.1 配置 Embedding 推理提供商

```yaml
providers:
  embedding:
    type: remote
    provider: openai-compatible
    base_url: https://<your-foundry-endpoint>
    api_key: <your-api-key>
    model: text-embedding-3-small
```

说明：

- Foundry 提供兼容 OpenAI 的 API
- 可以直接复用 Semantic Router 的远程 Embedding 推理提供商
- 无需额外适配

### 7.2 路由器工作流

```text
用户请求
   ↓
Semantic Router
   ↓
Microsoft Foundry Embedding 推理 API
   ↓
向量相似度计算
   ↓
路由决策
   ↓
目标模型（vLLM / API）
```

## 8. 相比官方教程的主要改进

| 能力     | 原始方案          | Microsoft Foundry 方案 |
| -------- | ----------------- | ---------------------- |
| 嵌入来源 | 本地 / 模拟       | 云端高质量模型         |
| 部署成本 | 需要模型或容器    | 零运维                 |
| 可扩展性 | 单一环境          | 多区域                 |
| 语义质量 | 中等              | 企业级                 |

## 9. 实际价值

### 🚀 1. 真正的“无 GPU 架构”

路由器本身运行在 CPU 上。

Embedding 模型与推理能力完全外部化：

- Foundry → Embedding 模型
- vLLM / API → 推理

### 🧠 2. 更准确的语义路由

在教程场景中：

```text
"What is 1+1?" → math 路由
"Tell me a joke" → general 路由
```

使用 Foundry 嵌入后，可以获得：

- 更稳定的语义理解
- 更好的多语言支持
- 对边界场景更准确的判断

### 🌐 3. 统一的多模型入口

结合 Semantic Router：

- Microsoft Foundry（Embedding 模型）
- vLLM（自托管推理）
- OpenAI / 其他 API

从而实现真正的：

> **多提供商智能路由**

## 10. 架构洞察

此次升级的本质是：

```text
升级前：
路由器 = 基础设施 + 智能

升级后：
路由器 = 智能
Foundry = AI 能力
```

由此形成清晰的分层架构：

```text
[ AI 能力层 ] → Microsoft Foundry
[ 路由层    ] → Semantic Router
[ 推理层    ] → vLLM / APIs
```

## 11. 总结

通过将 Microsoft Foundry 与官方远程 Embedding 模型教程相结合，我们实现了一套生产就绪的架构：

- 无需本地 Embedding 模型
- 无需 GPU
- 高质量的语义能力
- 企业级可靠性

这不仅是一次功能增强，更是 Semantic Router 的一次关键演进：

> 从“本地工具”演进为“云原生 AI 路由层”
