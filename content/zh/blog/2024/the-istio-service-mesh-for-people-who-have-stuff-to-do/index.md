---
title: "为繁忙的人们准备的 Istio 服务网格"
description: 翻译文章：了解 Luca Cavallin 使用 Istio 的经验。
publishdate: 2024-10-10
attribution: "Luca Cavallin - GitHub; Translated by Wilson Wu"
tags: [istio,open-source,service-mesh,cncf]
---

[原文地址（英文）：The Istio Service Mesh for People Who Have Stuff to Do](https://www.lucavall.in/blog/the-istio-service-mesh-for-people-who-have-stuff-to-do)

我最近为开源服务网格项目 **Istio** 做出了一点贡献。
我的贡献包括为 Istio CLI 命令之一添加一些测试。如果您想查看详细信息，
可以在[此处](https://github.com/istio/istio/pull/51635)找到 Pull Request。
这不是一个巨大的变化，但却是一次很棒的学习经历。在 Istio 上工作帮助我更深入地了解服务网格。
我很高兴能做出更多贡献。在这篇文章中，我将解释 Istio 是什么、它为什么有用以及它是如何工作的。

## Istio 是什么？ {#what-is-istio}

从本质上讲，Istio 是一种**服务网格**。服务网格管理微服务之间的通信，
处理诸如路由流量、保护通信和提供可观察性等事务。随着微服务数量的增加，
管理这些交互会变得复杂。Istio 可以自动执行其中许多任务，
因此您可以专注于构建应用程序，而不是管理服务到服务的通信。

## 为什么要使用 Istio？ {#why-use-istio}

随着架构变得越来越复杂，您将面临新的挑战。
服务需要以可靠、安全和高效的方式进行通信。Istio 可在三个关键领域帮助您实现此目标：

1. **管理流量**：Istio 让您可以控制服务之间的流量流动方式。
   您可以在服务的不同版本之间拆分流量，在部署期间重新路由请求，或设置重试和超时策略。
2. **确保通信安全**：Istio 可以轻松启用**双向 TLS（mTLS）**。
   这可确保服务之间的所有通信都经过加密和身份验证，从而阻止未经授权的服务进入。
3. **可观察性**：Istio 自动收集指标、日志和链路，让您实时了解服务。这有助于监控、故障排除和性能调整。

这三个领域 - 流量管理、安全性和可观察性是运行健康的微服务架构的关键，Istio 可以轻松处理它们。

## 通过 Istio 管理流量 {#managing-traffic-with-istio}

Istio 的主要功能之一是管理服务之间的流量。在微服务设置中，
您可能同时运行多个版本的服务。例如，您可能正在测试支付服务的新版本，
并希望将大部分流量发送到版本 1，但将部分流量路由到版本 2。

以下是如何使用 Istio 在服务的两个版本之间分割流量的示例：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: payments
spec:
  hosts:
  - payments.myapp.com
  http:
  - route:
    - destination:
        host: payments
        subset: v1
      weight: 90
    - destination:
        host: payments
        subset: v2
      weight: 10
```

在这个示例中：

- **90% 的流量**发送到 `payments` 服务版本 1，**10%** 发送到版本 2。
- `hosts` 字段指定 VirtualService 适用的域 - 在本例中为 `payment.myapp.com`。
- `route` 部分定义流量如何在服务的两个 subset 之间分配：`v1`（用于版本 1）和 `v2`（用于版本 2）。`weight` 字段控制流量分配。

这对于**金丝雀发布**非常有用，在全面推出新功能之前，您可以先与一小部分用户一起测试新功能。

### Envoy 代理和 Sidecar 容器 {#envoy-proxy-and-sidecar-containers}

Istio 的**数据平面**依赖于 **Envoy 代理**，这是一个七层代理，
用于管理服务之间的所有流量。网格中的每个服务都有自己的 **Sidecar 代理**，
它位于服务旁边并管理其所有入站和出站流量。

Envoy 允许您应用重试、超时和熔断等流量策略，而无需更改应用程序代码。
它还收集有关流量的详细指标，帮助进行监控和调试。

由于 Envoy 作为 **Sidecar 容器**运行，因此它可以执行这些规则并收集数据，
而不会干扰应用程序的逻辑。简而言之，Envoy 充当服务网格中所有通信的“交通警察”。

## 可观察性：了解系统中发生的情况 {#observability-seeing-whats-happening-in-your-system}

运行包含许多微服务的系统可能会让您难以看清正在发生的事情。
Istio 的内置**可观察性**功能可帮助您跟踪服务之间所有通信的指标、日志和链路。
这对于监控系统运行状况、发现性能问题和修复错误至关重要。

Istio 的可观察性工具让您清晰地了解系统的运行情况。您可以尽早发现问题，让您的服务运行得更顺畅。

## 安全性：启用 mTLS 和访问控制 {#security-enabling-mtls-and-access-control}

管理微服务时，安全性是一大问题。Istio 可以轻松实现**双向 TLS（mTLS）**，
它可以加密服务之间的所有通信，并确保服务在交换数据之前相互进行身份验证。

Istio 还允许您设置**访问控制策略**，以指定允许哪些服务进行通信。
这有助于限制哪些服务可以交互，从而减少系统的攻击面。

以下是 Istio 策略的示例，该策略仅允许 `billing` 服务与 `payments` 服务通信：

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payments-to-billing
spec:
  selector:
    matchLabels:
      app: payments
  rules:
  - from:
    - source:
        principals: ["billing.myapp.com"]
```

在这个策略中：

- `selector` 使用标签 `app: payments` 指定此规则适用于 `payments` 服务。
- `rules` 部分仅允许由主体 `billing.myapp.com` 标识的 `billing` 服务与 `payments` 进行通信。
  其他任何服务都不允许向 `payments` 发送流量。

此策略限制除 `billing` 之外的所有服务访问 `payments`，从而加强微服务的安全性。

### 什么是 SPIFFE？ {#what-is-spiffe}

Istio 使用 **SPIFFE**（面向所有人的安全生产身份框架：Secure Production Identity Framework for Everyone）来管理服务身份。
SPIFFE 提供了一种为服务分配安全、可验证身份的方法。网格中的每个服务都会获得一个 **SPIFFE 可验证身份文档（SVID）**，
该文档与 mTLS 一起使用以确保安全通信。该身份系统是 Istio 安全模型的基础。

## Istio 中的网络 {#networking-in-istio}

Networking in microservices can be difficult, especially when it comes to controlling traffic inside and outside the mesh. Istio provides several tools for managing network traffic:
微服务中的网络可能很复杂，特别是在控制网格内部和外部的流量时。Istio 提供了几种用于管理网络流量的工具：

- **Service Entry**：允许外部服务与网格内的服务进行通信，反之亦然。
- **Virtual Service**：定义网格内部流量的路由方式。
- **Destination Rule**：将流量策略（例如负载平衡或 mTLS）应用于服务。
- **Gateway**：管理进出网格的流量。

### 示例配置：Gateway，Service Entry，Virtual Service 以及 Destination Rule {#example-configuration-gateway-service-entry-virtual-service-and-destination-rule}

假设您的网格内有一个 API 服务器，它通过负载均衡器接收来自互联网的流量。
以下是配置 Gateway，Service Entry，Virtual Service 以及 Destination Rule 来处理此流量的方法。

```yaml
Gateway Configuration
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: api-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "api.myapp.com"
```

这里发生了什么？Gateway 在端口 80 上侦听来自域 `api.myapp.com` 的 HTTP 流量。选择器字段将此网关连接到 Istio 入口网关，后者处理进入网格的入站流量。

### Service Entry 配置 {#service-entry-configuration}

假设您的 API 服务器需要调用外部身份验证服务。您可以按如下方式配置 Service Entry：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: auth-service-entry
spec:
  hosts:
  - "auth.external-service.com"
  location: MESH_EXTERNAL
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  endpoints:
  - address: 203.0.113.1
```

这里发生了什么？ Service Entry 告诉 Istio 如何将流量路由到在端口 443（HTTPS）上运行的外部服务（`auth.external-service.com`）。`location: MESH_EXTERNAL` 表示此服务存在于 Istio 服务网格之外。`endpoints` 字段包含外部服务的 IP 地址，允许网格内的 API 服务器发送请求。

#### Virtual Service 配置 {#virtual-service-configuration}

以下是如何在网格内路由流量：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: api-virtualservice
spec:
  hosts:
  - "api.myapp.com"
  gateways:
  - api-gateway
  http:
  - match:
    - uri:
        prefix: "/v1"
    route:
    - destination:
        host: api-service
        subset: stable
```

这里发生了什么？Virtual Service 定义了流量路由规则。在本例中，通过 `api-gateway` 到达 `api.myapp.com/v1` 的流量被路由到网格中的 `api-service`。`subset: stable` 指的是 `api-service` 的特定版本（您可以拥有同一服务的多个版本）。

#### Destination Rule 配置 {#destination-rule-configuration}

最后，这是应用负载平衡和 mTLS 的 Destination Rule：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: api-destination-rule
spec:
  host: api-service
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    tls:
      mode: ISTIO_MUTUAL
```

这里发生了什么？目标规则将策略应用于路由到 api-service 的流量。它使用循环负载平衡在实例之间均匀分配请求。mTLS 已启用 `tls.mode: ISTIO_MUTUAL`，确保服务之间的加密通信。

### 弹性：使用重试、超时和断路处理故障 {#resiliency-handling-failures-with-retries-timeouts-and-circuit-breakers}

在分布式系统中，故障时有发生。服务可能会中断，网络可能会变慢，或者用户可能会遇到延迟。Istio 可通过重试、超时和断路器帮助您处理这些问题。

- **重试**：自动重试失败的请求以处理临时故障，而不会中断用户体验。
- **超时**：定义服务在放弃并继续之前应等待响应的时间。
- **断路**：如果某个服务出现故障，Istio 可以停止向其发送流量，从而防止可能导致系统其他部分崩溃的级联故障。

以下是如何在 Istio 中配置重试和超时的示例：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
    retries:
      attempts: 3
      perTryTimeout: 2s
    timeout: 5s
```

这里发生了什么？如果对 `my-service` 的请求失败，
Istio 将重试该请求最多 **3 次**。每次重试尝试都有 **2 秒的限制**。请求允许的总时间为 **5 秒**。此后，Istio 将停止等待响应。

对于熔断，你可以使用这样的 **Destination Rule**：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: my-service
spec:
  host: my-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
    outlierDetection:
      consecutive5xxErrors: 2
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

这里发生了什么？如果 `my-service` 在 **10 秒内连续返回两个 5xx 错误**，
Istio 将停止向其发送流量。该服务将从负载均衡池中被逐出 **30 秒**，然后再重新考虑。

### 总结 {#summary}

Istio 是一款功能强大的工具，可简化微服务的流量管理、安全性和可观察性。对 Istio 的贡献让我深入了解了它如何帮助解决运行分布式系统所带来的一些复杂挑战。

如果您正在运行微服务架构或计划扩展，Istio 可以帮助您提高系统弹性并更易于管理。如果您有任何疑问或想了解有关 Istio 的更多信息，请随时联系我们 - 我很乐意分享我所学到的知识。
