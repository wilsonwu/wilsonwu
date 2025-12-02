---
title: "Kubernetes Ingress NGINX Retirement: Comprehensive Migration Plan and Practice Guide to Gateway API"
description: 
publishdate: 2025-12-01
attribution: "Wilson Wu"
tags: [kubernetes,ingress,nginx,envoy,gateway]
---

On **November 11, 2025**, the official Kubernetes blog formally announced that the **Ingress NGINX project has entered the Retirement phase** and will cease maintenance entirely in **March 2026**.

This move marks the official entry of Kubernetes cluster ingress and traffic management into the **Gateway API era**. For teams currently using Ingress NGINX, this is not just a technical upgrade, but a risk management task that needs to be planned as soon as possible.

Based on the official Kubernetes retirement announcement, the latest Gateway API ecosystem, and community best practices, this article will systematically introduce:

* Why is Ingress NGINX being retired?
* The fundamental limitations of the Ingress model vs. the advantages of the Gateway API
* The new recommended alternative: Envoy Gateway (based on Gateway API)
* How to migrate from Ingress to Gateway API (complete migration path)
* Key considerations and production practice suggestions

## Why is Ingress NGINX officially retiring from Kubernetes?

According to the official blog (2025–11–11), the reasons for Ingress NGINX's retirement include:

### ● 1. Long-term lack of maintainers for the project

Although Ingress NGINX is widely used, the maintenance pressure is enormous, while the number of core maintainers is decreasing and community contributions are declining. After months of discussion, the project determined that it could not sustain investment.

### ● 2. Unable to keep up with the development of the Kubernetes networking model

Ingress was born in the early days of Kubernetes and only supports basic HTTP(s) routing; however, with the explosion of scenarios such as Service Mesh, multi-protocol services, and unified gateway governance, the Ingress model struggles to meet modern needs.

### ● 3. Functionality relies heavily on Controller private extensions

For example, NGINX Ingress's extensive Annotations, Rewrites, Header management, etc., make Ingress configurations highly incompatible between different controllers, making it difficult to form a unified abstraction for cloud-native networking.

### ● 4. Gateway API is mature and can fully replace it

Gateway API entered GA in 2023–2024, solving all the pain points of Ingress, and is the official strategic direction of Kubernetes SIG-Network for the next 10 years.

> The official announcement clarifies:
>
> * **From March 2026, no patches will be provided, including security patches.**
> * Project code, container images, and Helm Charts will remain accessible but will not be updated.
> * Officials advise users to "migrate as soon as possible".

## Limitations of Ingress: Why must it exit the stage of history?

The design of Ingress is very simple, capable only of the most basic L7 HTTP(s) routing:

| Capability | Ingress | Gateway API |
| :--- | :--- | :--- |
| Host / Path Routing | ✔ | ✔ |
| Header Matching | ❌ | ✔ |
| Query Matching | ❌ | ✔ |
| HTTP Method Matching | ❌ | ✔ |
| Traffic Splitting / Canary Release | ❌ | ✔ |
| Multiple Listening Ports | ❌ | ✔ |
| TCP / UDP / gRPC Multi-protocol | ❌ | ✔ |
| Multi-tenancy / RBAC Boundaries | Weak | Strong |
| Extensibility | Annotation chaos and incompatibility | CRD standard extension |

Ingress's capabilities can no longer support the needs of modern cloud-native systems, and behavior between controllers is extremely inconsistent. The emergence of the Gateway API is precisely to solve all the above problems.

![Architecture Comparison](1-ingress-vs-gateway-api.png)

## Recommended Alternative: Envoy Gateway + Gateway API

The current official recommendation is: **Switch to Gateway API and choose any compatible Gateway implementation**.

Among many implementations, we recommend **Envoy Gateway** for the following reasons:

### 1. Most complete support for Gateway API

Perfect support for HTTPRoute / TCPRoute / GRPCRoute, which Ingress cannot achieve.

### 2. Based on Envoy Proxy, industry-leading performance and scalability

Envoy is a CNCF graduated project, verified in large-scale production.

### 3. Active community, risk-free long-term maintenance

Compared to the "insufficient maintainers" of Ingress NGINX, Envoy Gateway is a clear long-term support project.

### 4. Native compatibility with Service Mesh (like Istio)

Gateway API will become the new standard for Service Mesh ingress in the future.

In other words: **Envoy Gateway is the safest migration target**.

![Envoy Gateway Architecture](2-envoy-gateway-architecture.png)

## Migration Path: From Ingress NGINX → Gateway API (Envoy Gateway)

Most enterprises are recommended to adopt **dual-stack migration**:

```text
Ingress (Old) and Gateway API (New) coexist → Migrate services one by one → Fully switch traffic → Uninstall Ingress NGINX
```

Here are the complete steps.

## Step 1: Install Gateway API and Envoy Gateway

Install standard Gateway API CRDs:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
```

Then install the Envoy Gateway controller (official Helm / YAML provided).

## Step 2: Create Gateway (Replacing Ingress Controller + LoadBalancer)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: infra
spec:
  gatewayClassName: envoy
  listeners:
  - name: http
    port: 80
    protocol: HTTP
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: demo-cert
```

This is equivalent to the original:

* Ingress Controller
* * LoadBalancer Service
* * TLS Configuration

## Step 3: Convert Ingress to Gateway API Routes

Original Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
spec:
  rules:
  - host: demo.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-svc
            port:
              number: 80
```

New HTTPRoute:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: demo
spec:
  parentRefs:
    - name: main-gateway
      namespace: infra
  hostnames:
    - "demo.example.com"
  rules:
  - matches:
      - path:
          type: PathPrefix
          value: "/"
    backendRefs:
      - name: demo-svc
        port: 80
```

## Step 4: Canary Traffic Switching (Optional but Highly Recommended)

Gateway API supports weights:

```yaml
backendRefs:
  - name: demo-svc-v1
    port: 80
    weight: 90
  - name: demo-svc-v2
    port: 80
    weight: 10
```

Used for:

* Canary releases
* Blue-green deployments
* Testing new gateways
* Gradually migrating traffic

This was previously only possible with Ingress using Nginx snippets.

## Step 5: Migrate Services One by One → Finally Replace All Ingress

Suggested migration order:

1. Stateless services
2. Internal services (non-public)
3. Low-risk traffic
4. High-risk / Core business
5. Global ingress traffic
6. Uninstall Ingress NGINX after completion

## Migration Considerations (Must-Read for Production)

### 1. Annotations will not migrate automatically

Ingress Annotations (rewrite, headers, timeouts, etc.) must be rewritten as Gateway API Policy / Filter.

### 2. TLS configuration is different

Gateway API handles TLS uniformly at the Listener layer.

### 3. Traffic switching should be gradual

Do not replace a large number of ingresses at once.

### 4. Start migration 6 months in advance

Complete the migration before maintenance stops in March 2026.

## Conclusion: Gateway API is the Future of Kubernetes Ingress

The retirement of Ingress NGINX is not a bad thing, but a sign that the Kubernetes networking system has completed its evolution.

**Ingress → Gateway API**
Is an inevitable trend and a comprehensive upgrade:

* Stronger routing capabilities
* Clearer multi-tenancy design
* Richer support for modern cloud-native scenarios
* Longer-term community maintenance guarantee

For teams already relying on Ingress NGINX, **migration planning should start now**.

Gateway API + Envoy Gateway is currently the most stable, modern, and recommended solution in the ecosystem.
