---
title: "Optimizing Inference with Parameter/Data (P/D) Separation in vLLM Framework"
description: As large language models grow in scale, inference deployment faces challenges of limited GPU memory and constrained concurrency. This article introduces how to leverage the vLLM framework to optimize inference performance through Parameter/Data (P/D) Separation. We will explain the principles, architectural design, configuration, and code examples, showing how to keep parameters permanently resident on dedicated GPUs while dynamically managing input sequences and KV Cache. This improves throughput, reduces costs, and enhances system scalability.
publishdate: 2025-09-29
attribution: "Wilson Wu"
tags: [azure,ai,llm,microsoft,vllm,pd,python,opensource,huggingface]
---

Large language models often encounter **GPU memory bottlenecks** during inference deployment:

* Model parameters (P) can reach hundreds of GB and must remain resident in GPU memory.
* Input/output data (D) changes dynamically with each request but is often coupled with parameters on the same device, leading to imbalanced memory usage and limited scalability.

To solve this problem, we can leverage the **vLLM framework** to implement **Parameter/Data (P/D) Separation**, improving the flexibility and throughput of inference systems.

## Resource Bottlenecks in LLM Inference

Take a 70B-parameter Transformer model as an example:

* Parameter weights (stored in FP16) require about **140GB of GPU memory**;
* Each request’s input sequence and KV Cache consume additional memory, which grows rapidly with batch size.

If P and D are placed on the same GPU without distinction:

1. Parameters permanently occupy memory, squeezing out space for dynamic data;
2. With multiple concurrent requests, memory for data becomes insufficient, limiting throughput.

Therefore, in distributed inference systems, the industry is increasingly adopting the architectural idea of **Parameter/Data Separation**.

## Introduction to vLLM

[vLLM](https://vllm.ai/) is a high-performance inference engine for large models, with core advantages including:

* **PagedAttention**: Efficient KV Cache management, enabling large-scale concurrency;
* **High throughput**: Several times faster than Hugging Face Transformers inference;
* **Flexible distributed support**: Compatible with DeepSpeed, Megatron, etc., supporting distributed storage and scheduling of parameters/data.

Thanks to its modular architecture, vLLM is naturally suited for implementing **P/D Separation**.

## Implementation Concept of P/D Separation

In vLLM, the inference workflow is roughly divided into two parts:

1. **Parameter Side (P)**  
   * Model weight loading and storage;  
   * Use strategies such as **ZeRO-3 / Tensor Parallelism** to distribute parameters across multiple GPUs;  
   * Parameters remain resident throughout inference and do not fluctuate with requests.

2. **Data Side (D)**  
   * Dynamic input sequences, KV Cache, sampling states, etc.;  
   * Use **PagedAttention** to manage GPU memory paging;  
   * Part of the KV Cache can be stored in CPU/Host memory and migrated to GPU on demand.

## Core Mechanism

The core mechanism is memory resource isolation:

* **Weights (P)** are permanently placed on dedicated GPUs (parameter nodes);
* **Data (D)** is allocated to other GPUs (data nodes) as needed, or even to CPU memory/NVMe.

This way:

* Parameter memory is not competed for by dynamic data;
* Data can scale dynamically with requests, enhancing concurrency.

## Implementation Path in vLLM

Common methods for P/D Separation:

1. **Parameter Sharding**  
   * Use vLLM’s support for Megatron-LM / DeepSpeed to shard parameters across GPUs;  
   * Aggregate only during inference computation, without storing the full model on each device.

2. **KV Cache Separation (Data Sharding)**  
   * With vLLM’s **PagedAttention**, KV Cache can be stored in separate GPUs or Host memory;  
   * Pages are swapped on demand during inference, similar to an OS virtual memory mechanism.

3. **Pipeline Parallelism**  
   * Divide model computation into stages: earlier layers run on parameter nodes, later layers on data nodes;  
   * Data passes through the pipeline stage by stage, while parameters remain sharded and resident.

## Hands-on P/D Separation with vLLM

We will provide two parts:

* **Configuration example**: How to specify parameter and data placement in a multi-GPU environment;  
* **Code example**: How to load the model and run inference with parameters resident and data dynamically allocated.

## Configuration Example

Suppose we have 4 GPUs:

* **GPU 0,1**: Dedicated for model parameters (P);  
* **GPU 2,3**: Mainly for KV Cache and dynamic data (D).

We can start vLLM with:

```bash
CUDA_VISIBLE_DEVICES=0,1,2,3 \
python -m vllm.entrypoints.api_server \
    --model /path/to/llama-2-70b \
    --tensor-parallel-size 2 \
    --gpu-memory-utilization 0.85 \
    --enable-chunked-prefill \
    --enforce-eager \
    --kv-cache-dtype fp16 \
    --max-num-batched-tokens 4096
```

Key points:

* `--tensor-parallel-size 2`: Store parameter shards only on GPU 0,1;
* `--gpu-memory-utilization`: Control parameter memory usage, leaving space for data;
* `--kv-cache-dtype fp16`: Reduce KV Cache precision to save data memory;
* **vLLM’s PagedAttention** automatically allocates KV Cache to GPU 2,3, falling back to CPU memory if needed.

## Code Example

Here’s a Python example:

```python
from vllm import LLM, SamplingParams

# -------- Parameter (P) Separation --------
# tensor_parallel_size=2 means parameters are distributed across GPU 0,1
llm = LLM(
    model="/path/to/llama-2-70b",
    tensor_parallel_size=2,
    gpu_memory_utilization=0.85,
    enforce_eager=True,       # avoid memory fragmentation
    enable_chunked_prefill=True,
    kv_cache_dtype="fp16"     # Data (D) uses lighter cache precision
)

# -------- Data (D) Separation --------
# PagedAttention automatically manages KV Cache placement (GPU2,3 or CPU memory)
sampling_params = SamplingParams(
    temperature=0.8,
    top_p=0.95,
    max_tokens=256
)

prompt = "Explain the benefits of implementing P/D Separation with vLLM."

# Run inference
outputs = llm.generate([prompt], sampling_params)

print("Model output:")
for output in outputs:
    print(output.outputs[0].text)
```

## Verification

During runtime, use `nvidia-smi` to observe:

* GPU 0,1 memory remains stable, holding parameters;
* GPU 2,3 memory fluctuates with request count/sequence length, holding KV Cache;
* If inputs are too large, KV Cache spills over to CPU memory, but inference continues.

## Practical Effects and Benefits

With P/D Separation, the benefits are:

* **Improved GPU utilization**: Clear division between parameters and data avoids memory conflicts;
* **Support for larger batch sizes**: Scalable data memory yields higher throughput;
* **Lower costs**: Parameters can reside on high-end GPUs, while data can use mid-range GPUs or CPU memory in a tiered storage design;
* **Flexibility**: Adapts to diverse hardware setups (A100 + H100, GPU + CPU, GPU + NVMe).

In practice, combined with vLLM’s PagedAttention, P/D Separation significantly boosts concurrency—achieving **multiple times higher throughput** on the same hardware.

## Conclusion

With efficient KV Cache management and distributed capabilities, the vLLM framework provides a solid foundation for **P/D Separation in LLM inference**.
By decoupling **parameters (P)** and **data (D)**, we can better utilize hardware resources, improving inference performance and scalability.

Looking ahead, with advances in **mixed-precision storage and hierarchical caching (GPU+CPU+NVMe)**, P/D Separation will likely become the mainstream paradigm for large model inference.
