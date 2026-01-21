---
title: "Microsoft TRELLIS: A Large Model for Production-Grade 3D Asset Generation and Guide to Deployment on Azure"
description: 
publishdate: 2026-01-19
attribution: "Wilson Wu"
tags: [azure,ai,trellis,3d,llm,python,model,vm]
---

![Trellis-3D](1-trellis-3d.png)

At the end of 2025, Microsoft Research released an open-source large model project for 3D content creation called **TRELLIS**, accompanied by the academic paper ["Structured 3D Latents for Scalable and Versatile 3D Generation"](https://arxiv.org/abs/2412.01506). This project significantly improves the quality and flexibility of text/image-to-3D asset generation through a unified structured latent space and advanced flow model technology. It also expands the multi-format output and editing capabilities of 3D models, making it one of the key technologies in the current 3D AI model ecosystem.

Official Github Repository: [https://github.com/microsoft/TRELLIS](https://github.com/microsoft/TRELLIS)

## What is TRELLIS? — Core Concepts and Architecture

TRELLIS is a **large 3D asset generation model** built by Microsoft that supports text prompts or image inputs and outputs high-quality 3D model assets. Its main technological innovations include:

* **Unified Structured Latent Representations (SLAT)**: Encodes 3D information into a scalable structured latent space representation, allowing the model to understand and generate 3D results in different forms in a unified way.
* **Rectified Flow Transformers**: A generative backbone network designed for SLAT, improving generation efficiency and quality by adapting to sparse representations.
* **Large-scale Training and Pre-trained Models**: The model scales up to **approximately 2 billion parameters** and is trained on a dataset containing **500,000 diverse 3D assets**, possessing strong generalization capabilities.

TRELLIS can generate not only 3D geometry but also capture complex texture and appearance information, making the generated assets closer to usable 3D content in the real world.

## Key Features

The following are the core functional modules and technical highlights of TRELLIS:

### Multi-modal Input Capabilities

TRELLIS supports the following input conditions:

* **Text-to-3D**: Generate 3D assets through natural language descriptions (prompts must be clear and accurate).
* **Image-to-3D**: Generate corresponding 3D models based on one or more images.

This multi-modal input support makes TRELLIS suitable for the entire creation process from concept design to real prototypes.

![3D](2-to-3d.png)

### Flexible Output Formats

Depending on downstream needs, TRELLIS outputs include:

* **Radiance Fields (NeRF)**: Suitable for rendering and display.
* **3D Gaussian Splatting**: A renderable density representation.
* **Traditional Mesh**: Can be exported to standard 3D file formats (e.g., GLB/OBJ) for games, AR/VR, and other applications.

This format flexibility is a key capability for the model to land in actual production environments.

### Local 3D Editing and Variant Generation

Unlike early single-generation models, TRELLIS enables:

* **Local Editing**: Make detailed modifications to existing models.
* **Variant Generation**: Create multiple output versions with different styles and details while maintaining the basic structure.

This capability is particularly suitable for iterative 3D content design.

### Support for Large-scale Dataset Training and Scalability

TRELLIS is trained on large-scale 3D datasets from multiple sources (such as Objaverse, ABO, etc.), giving it:

* **Strong Generalization Ability**
* **Richer Geometry and Texture Performance**
* **Multi-task Adaptation Ability**

Such a data foundation is one of the fundamental reasons for its advantages over competing products.

## Comparison with Competitors: Advantages and Improvements

Currently, other well-known 3D generation models on the market (such as **OpenAI Shap-E**, or research models like MeshGen) mostly have the following limitations:

* Some can only output a single 3D representation (such as implicit functions or point clouds).
* Most do not support local editing and multi-format output.
* Limited effectiveness in complex texture and detail representation.

In comparison:

### TRELLIS's Main Advantages Include

1. **Structured Latent Representation (SLAT) Framework**: Supports a unified generation and decoding mechanism while balancing geometry and texture details.
2. **Multi-format Generation Output**: More versatile than competitors that only generate a single data structure.
3. **Local Editing and Variant Generation**: Improves design iteration efficiency.
4. **Large-scale Pre-training and Richer Dataset Support**: Enhances the model's ability to generate rare or complex objects.

Overall, TRELLIS is more inclined towards being an industrial-grade 3D generation tool, rather than just a research display or a single generation model.

## Deployment and Usage

Currently, Microsoft does not yet offer TRELLIS directly as a Serverless or managed model in **Azure AI Foundry / Microsoft Foundry**. Therefore, the **most feasible and stable way** to use TRELLIS in the Azure cloud environment is through self-hosted deployment based on **Azure GPU Virtual Machines (VM)**.

This method has the following advantages:

* Full control over model version and inference process.
* Support for large memory GPUs, suitable for 3D model generation scenarios.
* Seamless integration with existing enterprise Azure network, security, and storage systems.

### 1. Azure GPU VM Sizing Recommendations

TRELLIS is a **VRAM and compute-sensitive 3D generation model** that requires high GPU resources. The following specifications are recommended:

#### Recommended VM Series

* **Standard_NC A100 v4** (A100 80GB, Preferred)
* **Standard_NC A100 v5** (A100 80GB, New Generation)
* **Standard_ND H100 v5** (H100, if higher throughput is needed)

> Practical Advice:
>
> * **Inference / Demo**: Single card A100 80GB is sufficient.
> * **High Resolution / Batch Generation / Editing Tasks**: Multi-card on a single machine or higher specifications are recommended.

### 2. Operating System and Base Environment

Recommended environment combination:

* OS: Ubuntu 20.04 / 22.04 LTS
* CUDA: Official version matching the VM driver
* Python: 3.8 or above
* PyTorch: Official CUDA version

You can select the **CUDA + NVIDIA Driver pre-installed image** directly from the Azure Marketplace, which significantly reduces environment preparation costs.

### 3. TRELLIS Installation and Dependency Configuration

#### Pull Code

```bash
git clone --recurse-submodules https://github.com/microsoft/TRELLIS.git
cd TRELLIS
```

#### Create Independent Python Environment and Install Dependencies

The official automation script is provided:

```bash
./setup.sh --new-env --basic
```

If you need to support training, editing, or advanced features, you can enable the corresponding parameters according to the official instructions.

### 4. Inference Execution on Azure VM

#### Method 1: Command Line Inference (Suitable for Batch Tasks)

Text or image-driven 3D model generation:

```bash
python example_text.py \
  --prompt "a futuristic electric motorcycle" \
  --output_dir outputs/
```

Or multi-image condition input:

```bash
python example_multi_image.py \
  --input_images images/ \
  --output_dir outputs/
```

Generated results can be directly exported to Mesh / Radiance Field and other formats for subsequent rendering or toolchain integration.

#### Method 2: Gradio Web UI (Recommended for Demo and Verification)

TRELLIS officially provides a Web Demo based on Gradio, suitable for:

* Internal team experience
* Product verification
* Algorithm effect comparison

```bash
python app.py
```

Then access the Web UI via the Azure VM public IP or internal load balancer.

### 5. Engineering Deployment Suggestions on Azure

To better run TRELLIS on Azure in the long term, the following architectural practices are recommended:

#### Storage Decoupling

* Model Weights: Azure Blob Storage
* Generated Results: Blob / Azure Files
* Logs and Metadata: Azure Monitor / Log Analytics

#### Service Encapsulation

* Use **FastAPI / Flask** to encapsulate TRELLIS inference as an HTTP API.
* GPU VM as the inference node.
* Frontend or workflow calls via REST.

#### Security and Networking

* Place VM inside a VNet.
* Access Web UI / API via Application Gateway or internal access.
* Support private deployment to meet enterprise security requirements.

## Summary and Outlook

Microsoft TRELLIS represents a significant advancement in current 3D AI generation technology, with significant advantages in generation quality, format diversity, and localized editing capabilities. For developers and designers looking to automate 3D content creation, it is a powerful open-source solution. Regarding deployment, although it is not yet officially offered as a serverless model in Foundry, TRELLIS inference and custom training can be efficiently run in the cloud through Azure's standard model deployment pipelines and GPU computing capabilities.
