---
title: "Let Models Choose Models: Embedding-Driven Smart Routing for LLMs"
description: 
publishdate: 2026-05-26
attribution: "Wilson Wu"
tags: [azure,ai,embedding,gateway,llm,python,model,smart,semantic,router]
---

In an AI architecture where multiple models coexist, such as GPT-4, GPT-4o, lightweight models, and vertical-domain models, one core question is:

> **How can the system automatically select the most suitable model without explicitly specifying a model ID?**

This article introduces an engineering-friendly approach:

> **Use an embedding model to calculate user intent, perform semantic matching at the gateway layer, and dynamically route the request to the most suitable upstream model service.**

We will use:

* Embedding model: Azure OpenAI `text-embedding-3-small`
* Gateway: Envoy
* Core mechanism: vector similarity scoring + policy-based routing

## Background and Motivation

In real production environments, large model calls usually face several challenges.

### 1. Cost and Performance Trade-Offs

| Model type | Strengths | Weaknesses |
| ---- | ---- | ---- |
| Large models, such as GPT-4 | Strong capability | High cost / high latency |
| Small models, such as GPT-4o-mini | Fast / inexpensive | Limited capability |
| Specialized models | Accurate | Weak generalization |

Different requests should go to different models instead of using a one-size-fits-all approach.

### 2. Limitations of Traditional Approaches

Common strategies include:

* Manually specifying `model_id` - not intelligent
* Rule-based routing with `if/else` - hard to scale
* Keyword matching - not semantically robust

### 3. Ideal Goal

What we want is:

> The user only enters a prompt, and the system automatically understands the intent and selects the optimal model.

This is exactly where embeddings can help.

## Core Principle: Embedding-Driven Semantic Routing

### 1. What Embeddings Are

An embedding model, such as `text-embedding-3-small`, maps text into a high-dimensional vector:

```
"Write a Python sorting function"
-> [0.012, -0.98, ..., 0.33]  (1536-dimensional vector)
```

Texts with similar meanings will have vectors that are closer to each other.

### 2. Routing Idea

The core logic can be summarized as:

```
User request -> Embedding -> Compare with intent prototype library -> Select best match -> Route to model
```

### 3. Intent Prototypes

We define a group of intent vectors in advance:

| Intent type | Example texts | Target model |
| ---- | ---- | ---- |
| Code generation | "write code", "generate function" | GPT-4 |
| Simple Q&A | "what is", "define" | GPT-4o-mini |
| Translation | "translate this" | Lightweight model |
| Long-form writing | "write blog" | GPT-4 |

These texts are embedded and cached ahead of time.

### 4. Similarity Calculation

A commonly used method is:

* Cosine Similarity, recommended

```
similarity = cosine(query_embedding, intent_embedding)
```

Then choose the highest score:

```
argmax(similarity_i)
```

## System Architecture

The overall architecture looks like this:

```
                +--------------+
                |   Client     |
                +------+-------+
                       |
               +-------v--------+
               |  Envoy Gateway |
               | Smart Routing  |
               +-------+--------+
                       |
        +--------------+--------------+
        |              |              |
 +------v-----+ +------v-----+ +------v-----+
 | GPT-4      | | GPT-4o-mini| | Specialized|
 |            | |            | | Model      |
 +------------+ +------------+ +------------+
```

## Implementation Breakdown

### 1. Request Flow

#### Step 1: Get the User Request

```json
{
  "input": "Help me write an example Go HTTP server"
}
```

#### Step 2: Call the Embedding API

Using Azure OpenAI:

```http
POST https://{endpoint}/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-02-15-preview
```

Request body:

```json
{
  "input": "Help me write an example Go HTTP server"
}
```

#### Step 3: Calculate Similarity

Pseudocode:

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

#### Step 4: Dynamic Routing in Envoy

Write the result into a header:

```
x-llm-route: gpt-4
```

Envoy routes based on the header:

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

## Envoy Gateway Implementation Options

Envoy does not directly support vector computation, so it needs to be extended.

### Option 1: External Processing, Recommended

Envoy calls an external service through `ext_proc`:

```
Envoy -> ext_proc service -> Return routing decision -> Envoy forwards
```

The `ext_proc` service is responsible for:

* Calling the embedding model
* Calculating similarity
* Returning the header

### Option 2: WASM Plugin

Embed the logic inside Envoy:

* Advantage: low latency
* Disadvantage: more complex development, usually Rust or C++

### Option 3: Sidecar Router, Simple

```
Client -> Router Service -> Envoy -> Model
```

The router service handles all smart routing logic.

## Optimization Strategies

### 1. Vector Cache

Avoid repeated embedding calls:

```python
cache[input_hash] = embedding
```

### 2. Hierarchical Intents

Avoid overly coarse single-layer classification:

```
Level 1: code / Q&A / writing
Level 2: language / length / difficulty
```

### 3. Threshold Control

```python
if best_score < threshold:
    fallback_model = "gpt-4"
```

This helps prevent incorrect routing decisions.

### 4. Multi-Model Fusion, or Ensemble Routing

This can be extended into:

* Top-K model candidates
* A/B testing
* Weighted routing

### 5. Cost-Aware Routing

Combine routing with:

* Token budget
* User tier
* SLA

Then enhance the routing policy:

```python
if user == "free":
    prefer_small_model()
```

## Advantages

### Compared with Rule-Based Routing

| Dimension | Embedding routing |
| ---- | ---- |
| Semantic understanding | Strong |
| Scalability | High |
| Maintenance cost | Low |

### Compared with Manually Specifying Models

* Better user experience, because users do not need to care about models
* Automatically optimized cost
* Support for dynamic policies

## Practical Recommendations

### 1. Initial Stage

* Start with 5 to 10 intent prototypes
* Use manual labeling and tuning

### 2. Data-Driven Optimization

Record:

* User requests
* Routing results
* User feedback

Continuously optimize the intent embeddings.

### 3. Combine with an LLM Router

In the future, this can evolve into:

> Hybrid decision-making with a small model plus embeddings, also known as a Hybrid Router.

## Summary

The essence of this approach is:

> **Replace rules with embeddings, and use vector similarity to drive model selection.**

Key benefits:

* Lower cost, by intelligently choosing lightweight models
* Better quality, by sending complex tasks to stronger models
* Architectural decoupling, by separating routing logic from models

In the multi-model era, this kind of semantic-driven gateway will become a standard architecture component.
