---
title: "基于 Azure OpenAI 构建智能地址解析 Chrome / Edge 浏览器扩展插件"
description: 
publishdate: 2025-12-15
attribution: "Wilson Wu"
tags: [azure,ai,chrome,edge,extension,llm,autoaddr]
---

在电商和物流领域，有一个不起眼但极其耗时的痛点：**将复杂的地址格式正确的输入到物流系统固定的字段中**。客户发来的地址格式千奇百怪，有时是逗号分隔，有时连成一行，顺序也完全随机，经常还缺少省份或州等关键信息。

本文我想分享我是如何构建 **Auto Address** 的，这是一个利用 **Azure OpenAI** 的强大能力来解决这个问题的 Chrome 及 Edge 浏览器扩展插件，其界面和使用方式及其简单。

![主界面](1-main-interface.png)

## 问题：非结构化数据

想象一下收到这段文本：
> "张三 13800138000 广东省深圳市南山区科技园南区R2-B三楼"

为了发货，你需要将其拆解为：

- **姓名**: 张三
- **电话**: 13800138000
- **地址**: 科技园南区R2-B三楼
- **城市**: 深圳市
- **省份**: 广东省
- **国家**: 中国

手动处理成百上千个订单既繁琐又容易出错。正则表达式（Regex）可以处理某些情况，但当格式变化或用户有错别字时，它们往往无能为力。

## 解决方案：LLM 作为解析器

![Auto Address](2-auto-address.png)

像 Azure OpenAI（如：GPT-4 或 GPT-5）这样的大语言模型在理解上下文方面表现出色。它们能区分街道名称和城市名称，不是因为死板的规则，而是因为它们理解地址的**语义**。

我选择 **Azure OpenAI** 进行此项目主要有两个原因：

1. **企业级隐私**：发送到 Azure OpenAI 的数据不会用于训练公共模型。
2. **可靠性**：稳定的正常运行时间和性能。

## 技术揭秘：它是如何工作的

插件的核心逻辑出奇地简单。它获取用户的输入，并将其连同一组非常具体的指令发送到 Azure OpenAI API。

### 1. System Prompt (系统提示词)

“魔法”在于系统提示词。我们需要确切地告诉模型要做什么，更重要的是，如何格式化输出。

这是代码中实际使用的提示词：

```javascript
{
  role: "system", 
  content: "You are an address parser. Return ONLY a raw JSON object (no markdown code blocks) with keys: name, province, city, address, zip_code, country. If province/state is missing in the input, infer it from the city. Do not separate house number, include it in the address field."
}
```

**这里使用的关键技巧：**

- **角色定义**: "You are an address parser." (你是一个地址解析器)
- **输出约束**: "Return ONLY a raw JSON object". (仅返回原始 JSON 对象)。这防止模型添加像 "这是您的 JSON：" 这样的废话。
- **Schema 定义**: 我们明确列出了我们想要的键 (`name`, `province` 等)。
- **逻辑注入**: "If province/state is missing... infer it." (如果省/州缺失...推断它)。这将逻辑处理卸载给了 AI。

### 2. API 调用

扩展使用标准的 `fetch` API 与您的 Azure 部署进行通信。

```javascript
const url = `${baseUrl}openai/deployments/${azureDeployment}/chat/completions?api-version=2024-05-01-preview`;

const response = await fetch(url, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'api-key': azureApiKey
  },
  body: JSON.stringify({
    messages: [ /* ... prompt ... */ ],
    temperature: 0.1 // 以获得一致、确定的结果
  })
});
```

我们使用低 `temperature` (0.1)，因为我们不需要创造力；我们需要精确度。

### 3. 智能省份推断（“双重检查”）

有时，即使是最好的模型也会遗漏细节，或者输入太模糊。一个常见的问题是缺少省/州信息。

我在 `popup.js` 中实现了一个“回退”机制。如果解析结果有城市但没有省份，扩展程序会发起**第二次定向 API 调用**：

```javascript
if ((!addr.province || addr.province === '') && addr.city) {
  // ... 二次调用 ...
  messages: [
    {
      role: "system", 
      content: "You are a geography helper. Return ONLY the province/state name for the given city. Do not return JSON, just the name."
    },
    {
      role: "user", 
      content: `Which province/state is the city "${addr.city}"${countryContext}?`
    }
  ]
}
```

这确保了在用户看到数据之前，数据尽可能完整。

## Chrome / Edge 扩展架构

### Manifest V3 与 Side Panel (侧边栏)

该扩展基于 **Manifest V3** 构建，这是 Chrome / Edge 扩展平台的最新迭代。

我没有使用点击后就会关闭的传统弹出窗口，而是使用了 **Side Panel API** (`"permissions": ["sidePanel"]`)。这允许扩展程序停留在浏览器窗口的一侧。这对工作流程至关重要：用户可以在左侧查看发货单页面，同时在右侧查看解析出的地址数据。

### 隐私优先

首先使用前需要通过配置界面设置您要使用的 Azure OpenAI 信息：

![配置界面](3-options-interface.png)

主要的设计决策是**零中间服务器**。

- 扩展程序使用 `chrome.storage.sync` 将您的 API 密钥本地存储在浏览器中。
- 请求直接从**您的浏览器** -> **Azure OpenAI**。
- 扩展开发者不收集任何数据。

## 结语

通过结合 Chrome / Edge 扩展的灵活性和 Azure OpenAI 的智能，我们可以将繁琐的数据录入任务转化为一键操作。

代码已开源。欢迎查看、Fork 并构建您自己的 AI 驱动工具！

**GitHub Repo**: [https://github.com/wilsonwu/autoaddr](https://github.com/wilsonwu/autoaddr)

如果您使用的是 Microsoft Edge 浏览器，可以通过扩展插件市场安装本插件的最新版本：[Edge 浏览器扩展插件](https://microsoftedge.microsoft.com/addons/detail/auto-address-smart-ship/ieaphpecggbaiineilddheaghcolkbba)
