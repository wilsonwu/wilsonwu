---
title: "Fara-7B：微软推出的高效电脑操作代理模型"
description: "介绍微软最新发布的 Fara-7B 模型，这是一个专为电脑操作设计的 7B 参数模型，以及如何通过 vLLM 进行部署和使用。"
publishdate: 2025-11-29
attribution: "Wilson Wu"
tags: [microsoft,ai,slm,agent,vllm,fara-7b]
---

![Fara-7B](1-fara-7b.png)

微软研究院最近发布了 **Fara-7B**，这是一款专为电脑操作（Computer Use）设计的代理小语言模型（Agentic SLM）。与传统的聊天模型不同，Fara-7B 旨在通过像人类一样使用鼠标和键盘来完成任务。

## 什么是 Fara-7B？

Fara-7B 是一个拥有 70 亿参数的模型，基于 [Qwen2.5-VL-7B](https://arxiv.org/abs/2502.13923) 构建。它的主要特点包括：

* **视觉感知**：它通过视觉感知网页（截图）来操作，不需要依赖辅助功能树（Accessibility Trees）或额外的解析模型。
* **高效紧凑**：尽管只有 7B 参数，但在同类模型中实现了最先进的性能，甚至在某些基准测试中可以与更大的模型竞争。
* **端侧运行**：由于体积小，它可以在设备上本地运行，从而降低延迟并提高隐私安全性。

![使用](2-useage.png)

## 核心技术

Fara-7B 的训练利用了微软开发的合成数据生成管道，该管道基于 [Magentic-One](https://www.microsoft.com/en-us/research/articles/magentic-one-a-generalist-multi-agent-system-for-solving-complex-tasks/) 框架。它通过“观察-思考-行动”（observe-think-act）的循环来执行任务。

在每个步骤中，模型会接收：

1. 用户指令
2. 完整的操作历史
3. 最近的三张屏幕截图

然后，它会输出一个推理信息（“思考”下一步行动），随后调用工具（如 `click(x,y)`、`type()` 等）来执行操作。

![工作流程](3-workflow.png)

## 性能表现

在 WebVoyager、Online-Mind2Web 等基准测试中，Fara-7B 展现了强大的性能。例如在 WebVoyager 上，它的任务成功率达到了 73.5%，超过了 UI-TARS-1.5-7B (66.4%) 和 GPT-4o (SoM Agent, 65.1%)。

## 如何通过 vLLM 使用 Fara-7B

Fara-7B 已经发布在 [Hugging Face](https://huggingface.co/microsoft/Fara-7B) 上。由于它是基于 Qwen2.5-VL 的，我们可以使用 vLLM 来高效地部署和推理。

### 安装 vLLM

首先确保你安装了最新版本的 `vllm`：

```bash
pip install vllm
```

### Python 代码示例

以下是一个使用 vLLM 加载 Fara-7B 并进行推理的 Python 脚本示例：

```python
from vllm import LLM, SamplingParams
from PIL import Image
import requests
from io import BytesIO

def run_fara_7b():
    # 模型名称
    model_name = "microsoft/Fara-7B"

    # 初始化 LLM
    # Fara-7B 基于 Qwen2.5-VL，因此使用类似的配置
    llm = LLM(
        model=model_name,
        trust_remote_code=True,
        max_model_len=4096,  # 根据显存大小调整
        limit_mm_per_prompt={"image": 1},
        mm_processor_kwargs={
            "min_pixels": 28 * 28,
            "max_pixels": 1280 * 28 * 28,
        },
    )

    # 加载示例图片（这里仅作演示，实际使用中应为屏幕截图）
    image_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg"
    response = requests.get(image_url)
    image = Image.open(BytesIO(response.content))

    # 构建 Prompt
    # 注意：Fara-7B 使用特定的 Prompt 格式
    prompt = (
        "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n"
        "<|im_start|>user\n<|vision_start|><|image_pad|><|vision_end|>"
        "Describe this image in detail.<|im_end|>\n"
        "<|im_start|>assistant\n"
    )

    # 准备输入
    inputs = {
        "prompt": prompt,
        "multi_modal_data": {
            "image": image
        },
    }

    # 采样参数
    sampling_params = SamplingParams(temperature=0.2, max_tokens=512)

    # 生成结果
    outputs = llm.generate([inputs], sampling_params=sampling_params)

    for o in outputs:
        print(f"Generated text: {o.outputs[0].text}")

if __name__ == "__main__":
    run_fara_7b()
```

### 命令行启动 API 服务

如果你想启动一个兼容 OpenAI API 的服务，可以使用以下命令：

```bash
vllm serve microsoft/Fara-7B \
  --trust-remote-code \
  --limit-mm-per-prompt image=1 \
  --mm-processor-kwargs '{"min_pixels": 784, "max_pixels": 1003520}'
```

注意：`min_pixels` 对应 28x28，`max_pixels` 对应 1280x28x28。

## 总结

Fara-7B 是微软在代理小模型领域的一次重要尝试，它证明了小模型在复杂的电脑操作任务中也能有出色的表现。通过开源权重，开发者可以更轻松地探索和构建基于 GUI 的自动化代理。
