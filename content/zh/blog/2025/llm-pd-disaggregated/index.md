---
title: "大语言模型（LLM）推理加速：预填充（Prefill）和解码（Decode）解耦（PD 分离）"
description:
publishdate: 2025-12-22
attribution: "Wilson Wu"
tags: [ai,llm,vllm,pd-disaggregated,opensource]
---

随着大语言模型（LLM）在对话系统、智能助手和 Agent 场景中的广泛落地，推理系统面临的核心挑战已从“能不能跑”转向“**如何以更低延迟、更高吞吐、更稳定的方式运行**”。在这一背景下，**PD Disaggregated（Prefill / Decode 解耦）** 逐渐成为大规模在线推理系统中的关键架构思想。

本文将不依赖任何具体推理框架，从 **模型推理执行流** 的角度，系统阐述什么是 PD Disaggregated、为什么需要它，以及它为 LLM 推理系统带来的核心优势。

## LLM 推理的两个本质阶段

所有自回归大语言模型的推理过程，本质上都可以拆解为两个阶段：

![两个阶段](1-inference-2-phase.png)

### Prefill（预填充阶段）

Prefill 阶段负责处理用户输入的完整 Prompt，其主要任务包括：

* 对输入序列进行一次完整前向计算；
* 构建上下文对应的 KV Cache；
* 生成第一个输出 Token。

这一阶段具有如下特征：

* **计算密集型（Compute-bound）**
* 大规模矩阵乘法（GEMM）占主导
* 序列长度通常较长
* 对批处理（Batching）高度友好

### Decode（解码阶段）

Decode 阶段进入逐 Token 生成过程，每一步都会：

* 输入上一个生成的 Token；
* 读取历史 KV Cache；
* 生成下一个 Token，直到结束条件满足。

其特征与 Prefill 明显不同：

* **访存密集型（Memory-bound）**
* 计算规模小，但 KV Cache 访问频繁
* 强延迟敏感
* 执行步数随生成长度线性增长

## 问题根源：Prefill 与 Decode 的“异构性”

Prefill 与 Decode 并非同一类工作负载，它们在多个维度上呈现出**显著异构性**：

| 维度    | Prefill      | Decode          |
| ----- | ------------ | --------------- |
| 计算模式  | 大算子、密集计算     | 小算子、频繁访存        |
| 批处理需求 | 大 batch 效果最好 | batch 过大反而增加延迟  |
| 延迟容忍度 | 相对较高         | 极低              |
| 资源瓶颈  | 算力           | 显存带宽 / KV Cache |

如果将这两种阶段**混合部署、统一调度**，就会导致资源使用上的结构性低效。

## 什么是 PD Disaggregated

**PD Disaggregated（Prefill / Decode 解耦）**，指的是在推理系统架构层面：

> **将 Prefill 与 Decode 视为两类不同的工作负载，并在调度、资源分配甚至部署拓扑上对它们进行解耦设计。**

需要强调的是：

* 这并不是模型结构的拆分；
* 也不是参数的拆分；
* 而是**推理执行路径与资源使用方式的解耦**。

PD Disaggregated 的核心思想是：
**让 Prefill 为吞吐服务，让 Decode 为延迟服务。**

## 为什么必须进行 PD 解耦

### GPU 利用率的结构性浪费

混合执行时常见现象包括：

* Decode 阶段算子太小，GPU 算力无法被充分利用；
* Prefill 阶段的大算子又会阻塞 Decode；
* 结果是整体 GPU 利用率“看起来不低，但效率很差”。

PD 解耦后，可以针对不同阶段采用不同的调度和批策略，显著改善有效算力利用。

### 延迟不可预测，尾延迟恶化

在在线推理场景中，Decode 阶段直接决定用户体验：

* 首 Token 延迟（TTFT）
* 单 Token 延迟（TPOT）
* P99 / P999 延迟

如果 Decode 被 Prefill 阻塞，哪怕吞吐提升，用户体验也会显著下降。
PD Disaggregated 能从架构层面**隔离延迟敏感路径**。

### 扩展性受限

在混合架构下：

* Prefill 和 Decode 只能按同一比例扩容；
* 无法根据实际负载特征独立扩展某一阶段。

而真实业务中：

* Chat、Agent 场景 Decode 占比极高；
* 离线生成、批处理 Prefill 占比更高。

PD 解耦使得 **按阶段独立扩展成为可能**。

## PD Disaggregated 的典型架构形态

在工程实践中，PD Disaggregated 通常体现为以下形式之一：

### 调度级解耦（Soft Disaggregation）

* Prefill 与 Decode 共享模型参数；
* 但在调度层面对二者区别对待；
* Decode 拥有更高优先级。

这是最轻量、最容易落地的形态。

### 资源级解耦（Resource Disaggregation）

* Prefill 与 Decode 使用不同的 GPU 资源池；
* Prefill GPU 偏向算力型；
* Decode GPU 偏向显存带宽与 KV Cache 容量。

该模式在大规模集群中尤为常见。

### 服务级解耦（Service Disaggregation）

* Prefill 与 Decode 成为独立服务；
* 中间通过 KV Cache 或状态句柄连接；
* 可独立伸缩、独立调度。

这是 PD Disaggregated 的“完全形态”，也是复杂度最高的一种。

## PD Disaggregated 带来的核心优势

### 更高吞吐与更低延迟并存

传统架构往往需要在吞吐与延迟之间取舍，而 PD 解耦允许：

* Prefill 极致批量化；
* Decode 极致低延迟。

### 更稳定的尾延迟

Decode 不再被大规模 Prefill 阻塞，P99 / P999 延迟显著改善，这对生产系统至关重要。

### 更合理的资源利用

不同阶段匹配不同资源类型，避免“用算力型 GPU 跑访存密集任务”这类结构性浪费。

### 更强的系统演进能力

PD Disaggregated 为后续优化打开空间，例如：

* KV Cache 分层存储；
* Decode 专用硬件；
* 面向 Agent 的长时会话优化。

## 总结

PD Disaggregated 并不是某个框架的特性，而是**对 LLM 推理本质的抽象与再设计**：

* Prefill 和 Decode 在计算形态上天然异构；
* 强行混合只会掩盖效率问题；
* 解耦是走向规模化、高质量推理服务的必经之路。

可以预见，随着模型规模继续增长、应用形态日益复杂，**PD Disaggregated 将从“高级优化”演变为 LLM 推理系统的默认架构假设**。
