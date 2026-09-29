---
title: "用 Microsoft Web IQ 增强 OpenWebUI：零代码实现联网搜索与链接自动读取"
description: 
publishdate: 2026-09-28
attribution: "Wilson Wu"
tags: [openwebui,microsoft,webiq,websearch,llm,ai,agent,opensource]
---

![OpenWebUI 接入 Microsoft Web IQ](1-openwebui-web-iq.png)

在[上一篇文章](/blog/2026/migrate-openwebui-to-azure-pg/)中，我把 OpenWebUI 的数据库迁移到了 Azure 托管 PostgreSQL。在日常使用 OpenWebUI 的过程中，我经常遇到两个问题：

1. **问不到最新的信息**：模型有知识截止时间，问到最近的版本发布、新闻或价格，要么答不上来，要么答错。
2. **贴进去的链接不会被打开**：把文章、文档或 GitHub 页面的 URL 贴进对话框，想让模型总结、翻译或对比，模型却不会去读这个链接，有时甚至会根据 URL 猜出一段“看起来很像”的内容。

这两个问题都可以靠 OpenWebUI 的联网能力解决。本文使用微软新推出的 **Microsoft Web IQ** 作为联网搜索引擎，并让模型自动识别消息中的 URL、读取网页后再回答。整个过程只需要在 Azure 门户中创建一个 Web IQ 资源，再到 OpenWebUI 的管理界面中完成配置，**不需要写代码，也不需要部署额外的服务**。

> 本文基于 Open WebUI v0.11.4（2026 年 9 月发布），界面名称以英文界面为准。文中的 API Key 均为占位符。

## 最终效果

配置完成后：

- 提问涉及最新信息时，模型会自己调用 `search_web`，由 Web IQ 返回搜索结果，回答附带参考链接；
- 消息中出现 `http://` 或 `https://` 链接时，模型会自己调用 `fetch_url`，通过 Web IQ 读取页面正文后再回答，读取过的页面会出现在引用来源中；
- 两者可以在同一次回答中组合使用，例如先读取你给出的文档，再搜索最新的变更说明做对比。

## 为什么选择 Microsoft Web IQ

![Bing Search v7、Grounding with Bing Search 与 Web IQ 的接入方式对比](2-bing-vs-web-iq.png)

打开 OpenWebUI 的 **Settings → Admin → Web Search**，在 **Web Search Engine** 中可以找到 `bing`。选中后需要填写 **Bing Search V7 Endpoint** 和 **Bing Search V7 Subscription Key**，看起来只要填上 Azure 上 Bing 资源的密钥就能用，但这条路已经走不通了：

- Bing Search v7 API（包括 Bing Custom Search）已于 **2025 年 8 月 11 日退役**，已有实例全部下线，也无法再创建新资源；
- 现在 Azure 上能创建的 Bing 资源是 **Grounding with Bing Search**，它只能作为 Microsoft Foundry 智能体的工具使用，不能拿密钥直接调用搜索接口。想接入 OpenWebUI，就得自己开发一个桥接服务。

**Microsoft Web IQ** 是微软在 2026 年 6 月发布的一组面向 AI 应用的 API，用来为模型提供实时的网络信息（grounding），可以理解为“给 AI 智能体用的搜索引擎”：

- 基于 Bing 的全球索引构建，并针对智能体的多轮检索重新设计；
- 返回的不只是链接列表，而是带来源的相关段落，可以直接放进模型上下文，用更少的 token 得到更好的回答；
- 覆盖网页、新闻、图片、视频等内容，支持 100 多种语言和市场。

更重要的是，OpenWebUI 已经内置了 `microsoft_web_iq` 引擎。它既可以作为**搜索引擎**，也可以作为读取网页的**网页加载引擎**，只需要一个 API Key。

| 方案 | 在 OpenWebUI 中接入 | 现状 |
| --- | --- | --- |
| Bing Search v7 | 内置 `bing` 引擎 | 已退役，不可用 |
| Grounding with Bing Search | 自己开发桥接服务，通过 Foundry 调用 | 主要面向 Foundry 智能体 |
| Microsoft Web IQ | 内置 `microsoft_web_iq` 引擎，填写 API Key 即可 | 2026 年 6 月发布，目前为有限访问 |

## 工作原理

![OpenWebUI 通过 Web IQ 搜索和读取网页](3-how-it-works.png)

```text
用户消息
  │
  ▼
OpenWebUI（模型以原生工具调用方式工作）
  │
  ├── search_web：联网搜索
  │     └── Web IQ /search/web：返回标题、链接和相关段落
  │
  └── fetch_url：读取消息中的链接
        └── Web IQ /browse：读取网页，返回 Markdown 格式的正文
```

几点说明：

- `search_web` 和 `fetch_url` 是 OpenWebUI 的两个内置工具，同属 Web Search 类别，由模型自己决定何时调用；
- 这两个工具依赖原生工具调用（Native Function Calling），这是 v0.10.0 起的默认模式；
- 网页加载引擎也设为 Web IQ 之后，网页由 Web IQ 读取，需要 JavaScript 渲染的页面也能读到内容。PDF 等文件仍然由 OpenWebUI 下载后自行解析。

## 第一步：创建 Web IQ 资源并获取 API Key

Web IQ 以 Azure 资源的形式提供。在 Azure 门户中搜索 **Microsoft Web IQ**，进入 **Microsoft Web IQ resources**，点击 **Create**，在 **Basics** 页填写：

- **Subscription** 和 **Resource group**：选择用于管理和计费的订阅与资源组；
- **Name**：资源名称；
- **Region**：固定为 **Global**，这是一个可以跨 Azure 区域使用的全局资源。

![在 Azure 门户中创建 Microsoft Web IQ 资源](4-create-web-iq-resource.png)

点击 **Review + create** 完成创建，然后在资源页面中复制 API Key，下一步会用到。

Web IQ 目前仍处于**有限访问**（limited access）阶段。如果在 Azure 门户中找不到或者无法创建这个资源，可以先到 [Microsoft Web IQ 官网](https://www.microsoft.com/en-us/WebIQ) 点击 **Join the waitlist** 申请。

## 第二步：配置 Web IQ 搜索和网页读取

以管理员身份登录 OpenWebUI，点击左下角的头像，进入 **Settings → Admin → Web Search**。

### 1. Search 部分

| 设置项 | 值 | 说明 |
| --- | --- | --- |
| Web Search | 开启 | 全局开关 |
| Web Search Engine | `microsoft_web_iq` | 选中后会出现下面三项 |
| Microsoft Web IQ API Base URL | `https://api.microsoft.ai/v3` | 保持默认值 |
| Microsoft Web IQ API Key | `<WEB_IQ_API_KEY>` | 第一步获取的 API Key |
| Language | `en` | 搜索结果的语言代码，默认为 `en` |
| Search Result Count | `5` | 每次搜索返回的结果数量 |
| Fetch URL Content Length Limit | `50000` | `fetch_url` 最多返回的字符数，留空表示不限制 |

几点说明：

- **Microsoft Web IQ API Base URL**：OpenWebUI 已经预先填好，一般不需要修改；如果 Web IQ 资源页面显示了其他终结点，以资源页面为准；
- **Language**：技术类内容用 `en` 通常效果更好；如果主要查询中文资讯，可以改为 `zh`（以 Web IQ 支持的语言代码为准）；
- **Fetch URL Content Length Limit**：默认不截断，遇到很长的页面会占用大量上下文，建议设置上限；
- **Web Search Confirmation**：可选。开启后，用户在对话中使用联网搜索前会先看到确认提示，例如默认的 “Your query will be sent to the configured web search provider.”，提醒用户查询内容会发送到外部服务。

### 2. Loader 部分

| 设置项 | 值 | 说明 |
| --- | --- | --- |
| Web Loader Engine | `microsoft_web_iq` | 读取网页也交给 Web IQ，与搜索共用上面的 API Key |

点击 **Save** 保存，配置立即生效，不需要重启容器。

Web Loader Engine 也可以保持 **Default**，由 OpenWebUI 服务器自己抓取网页。但默认加载器读不到需要 JavaScript 渲染的内容，它的 User-Agent 也容易被部分网站拦截，交给 Web IQ 读取会省心很多。

## 第三步：让模型自动识别并读取消息中的 URL

![没有 fetch_url 时模型只能猜，有 fetch_url 时先读后答](5-read-before-answer.png)

### 1. 模型设置

进入 **Settings → Admin → Models**，编辑对话使用的模型：

| 位置 | 设置 |
| --- | --- |
| Capabilities | 勾选 **Web Search**、**Builtin Tools**、**Citations**、**Status Updates** |
| Builtin Tools | 确认 **Web Search**（Search the web and fetch URLs）已勾选 |
| Default Features | 勾选 **Web Search**，新对话默认打开联网开关 |
| Advanced Params | **Function Calling** 设为 **Native**（默认值） |

其中 **Default Features** 很关键：原生模式下，只有模型启用了 Web Search 能力，并且当前对话打开了联网开关，`search_web` 和 `fetch_url` 才会提供给模型。不勾选的话，用户每次都要在输入框的 **+** 菜单中手动打开联网搜索，否则贴进来的链接不会被读取。

原生模式要求模型具备可靠的工具调用能力，建议使用较新的模型，太小或太旧的模型可能不会正确调用工具。

### 2. 系统提示词

是否调用 `fetch_url` 由模型自己决定。为了让行为更稳定，在同一个页面的 **System Prompt** 中加入以下规则：

```text
你可以使用 search_web 和 fetch_url 两个工具：
1. 用户消息中出现以 http:// 或 https:// 开头的链接时，先调用 fetch_url 读取链接内容，再根据读取结果回答；有多个链接时逐个读取。
2. 问题涉及最新动态、版本、价格等时效性信息，或者你不确定答案时，调用 search_web 搜索；搜索结果中的摘要不够时，再用 fetch_url 打开最相关的结果。
3. 链接无法访问或内容为空时，如实告诉用户，不要根据链接地址推测页面内容。
4. 在回答末尾列出参考链接。
```

第 3 条用来防止模型在读取失败后“编”一段内容；第 4 条则是因为原生模式下，`search_web` 的结果不会出现在引用来源中，只有 `fetch_url` 读取过的页面才会，所以需要模型在回答中写出来。

### 3. 手动附加网页

如果希望某个链接一定被读取，也可以手动附加：

- 在输入框中输入 `#` 后粘贴链接，然后选择该网页；
- 或者通过输入框的 **+ → Attach Webpage** 添加链接。

这两种方式由 OpenWebUI 直接读取页面（同样使用上面配置的网页加载引擎），不依赖模型的判断。

## 效果验证

### 1. 读取链接

新建一个对话，输入：

```text
帮我总结这篇文档的要点：https://docs.openwebui.com/features/chat-conversations/web-search/providers/microsoft-web-iq
```

预期：

- 回答过程中显示模型调用了 `fetch_url`；
- 回答下方的引用来源中出现这篇文档；
- 回答内容与文档一致，而不是泛泛而谈。

### 2. 联网搜索

```text
Open WebUI 最新发布的版本是多少？有哪些主要更新？
```

预期：

- 模型调用 `search_web`，结果来自 Web IQ；
- 如果摘要不够，模型会继续调用 `fetch_url` 打开发布说明页面；
- 回答末尾列出参考链接。

### 3. 组合使用

```text
先读取 https://github.com/open-webui/open-webui/releases 的内容，再搜索一下社区对最新版本的反馈，最后给我一个是否升级的建议。
```

预期模型会先读取给出的链接，再根据需要多次搜索，最后综合两部分信息给出建议。

### 4. 排查问题

如果没有达到预期效果，可以先查看 OpenWebUI 的日志：

```bash
docker logs --since 10m open-webui 2>&1 |
grep -Ei 'web iq|microsoft browse|fetch_url|blocked'
```

常见的日志：

- `Error searching with Microsoft Web IQ API`：搜索请求失败，通常是 API Key 不正确或者尚未开通；
- `Error browsing ... with Microsoft Web IQ`：Web IQ 读取网页失败；
- `Blocked ...`：链接指向内网地址或者在过滤列表中，被 OpenWebUI 拦截。

也可以直接用 curl 验证 API Key，下面的请求格式与 OpenWebUI 实际发送的一致：

```bash
curl -sS https://api.microsoft.ai/v3/search/web \
  -H "x-apikey: $WEB_IQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "Open WebUI", "maxResults": 3, "language": "en", "contentFormat": "passage"}'
```

正常情况下会返回包含 `webResults` 的 JSON，每条结果都有 `url`、`title` 和 `content`。

## 注意事项

- **数据会发送到 Web IQ**：搜索词和需要读取的链接会发送到 Web IQ API（`api.microsoft.ai`），数据如何处理以 Web IQ 的服务条款为准。敏感对话可以关闭联网开关，或者开启 Web Search Confirmation 提醒用户。
- **请求中会附带用户信息**：从 v0.11.4 的源码看，调用 Web IQ 搜索时，OpenWebUI 会在请求头中附带当前用户的名称、ID、邮箱和角色（`X-OpenWebUI-User-*`），目前无法通过配置关闭。如果组织对此有要求，上线前需要评估。
- **内网链接无法读取**：读取链接之前，OpenWebUI 会先校验 URL，默认禁止访问内网地址和云元数据地址。这些防护默认开启，无需额外配置，Web IQ 本身也访问不到内网页面。
- **调用次数与成本**：每次 `search_web` 和 `fetch_url` 都是一次 Web IQ 调用，原生模式下模型还可能为一个问题连续调用多次。建议 Search Result Count 保持在 3～5，只在需要联网的模型上把 Web Search 设为默认功能。Web IQ 的费用计入创建资源时选择的 Azure 订阅，可以为资源组设置预算告警。

## 常见问题

| 现象 | 可能原因 | 处理方法 |
| --- | --- | --- |
| 贴了链接，模型说无法访问网页 | 对话没有打开联网开关，或者模型没有启用 Web Search 能力和内置工具 | 检查模型的 Capabilities、Default Features 和对话中的联网开关 |
| 模型根据 URL 编造内容 | 没有调用 `fetch_url` | 确认 Function Calling 为 Native，并加入系统提示词 |
| 普通用户看不到联网开关 | 用户组没有 Web Search 功能权限 | 在用户组的功能权限中允许 Web Search |
| 搜索始终没有结果 | API Key 错误或者尚未开通 | 查看日志，并用 curl 验证 API Key |
| 搜索结果的语言不符合预期 | Language 与查询的语言不一致 | 修改 Language |
| 部分网页读取失败 | 页面需要登录、禁止抓取，或者链接指向内网 | 换一个可以公开访问的链接，或者直接把正文粘贴到对话中 |

## 总结

Bing Search API 退役之后，OpenWebUI 内置的 `bing` 引擎已经无法使用。借助 OpenWebUI 内置的 `microsoft_web_iq` 引擎，只需要在 Azure 上创建一个 Web IQ 资源并拿到 API Key，就可以在管理界面中完成联网搜索的接入：

- 搜索和网页读取都交给 Web IQ，返回的是适合直接放进模型上下文的段落和正文；
- 在原生工具调用模式下，`search_web` 负责搜索，`fetch_url` 负责读取消息中的链接；
- 通过模型的 Default Features 和系统提示词，让模型自动识别 URL、先读后答，并在回答中给出参考链接。

整个过程不需要写一行代码。无论是询问最新的信息，还是直接丢一个链接让模型总结，现在都可以在 OpenWebUI 中完成。

## 参考资料

- [Announcing Microsoft Web IQ](https://blogs.bing.com/search/2026/6/Announcing-Microsoft-Web-IQ/)
- [Microsoft Web IQ](https://www.microsoft.com/en-us/WebIQ)
- [Open WebUI: Microsoft Web IQ](https://docs.openwebui.com/features/chat-conversations/web-search/providers/microsoft-web-iq)
- [Open WebUI: Agentic Web Search & URL Fetching](https://docs.openwebui.com/features/chat-conversations/web-search/agentic-search)
- [Open WebUI: Bing](https://docs.openwebui.com/features/chat-conversations/web-search/providers/bing)
- [Open WebUI: Hardening](https://docs.openwebui.com/getting-started/advanced-topics/hardening)
