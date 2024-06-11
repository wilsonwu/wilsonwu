---
title: "Envoy Gateway Usage on Azure AKS"
description: In this blog post, we will explore how to use Envoy Gateway on Azure AKS (Azure Kubernetes Service). Envoy Gateway is a powerful edge and service proxy that provides advanced load balancing, routing, and observability capabilities.
publishdate: 2024-05-13
attribution: "Wilson Wu"
keywords: [aks,envoy,gateway,k8s,kubernetes]
---

In this blog post, we will explore how to use Envoy Gateway on Azure AKS (Azure Kubernetes Service). Envoy Gateway is a powerful edge and service proxy that provides advanced load balancing, routing, and observability capabilities.

## Prerequisites

Before we begin, make sure you have the following prerequisites:

1. An Azure subscription
2. Azure CLI installed on your local machine
3. A running AKS cluster

## Step 1: Deploying Envoy Gateway

To deploy Envoy Gateway on Azure AKS, follow these steps:

1. Create a Kubernetes deployment manifest for Envoy Gateway.
2. Apply the deployment manifest to your AKS cluster using the `kubectl apply` command.
3. Verify that the Envoy Gateway deployment is running successfully.

## Step 2: Configuring Envoy Gateway

Once the Envoy Gateway is deployed, you need to configure it to handle incoming traffic and route it to the appropriate services. This can be done by creating a configuration file that defines the listeners, routes, and filters for Envoy.

## Step 3: Testing Envoy Gateway

After configuring Envoy Gateway, it's important to test its functionality. You can do this by sending requests to the gateway and verifying that they are properly routed to the intended services.

## Step 4: Monitoring and Observability

Envoy Gateway provides powerful monitoring and observability features that allow you to gain insights into the traffic flowing through your cluster. You can use tools like Prometheus and Grafana to visualize and analyze the metrics collected by Envoy.

## Conclusion

In this blog post, we have covered the usage of Envoy Gateway on Azure AKS. By following the steps outlined above, you can leverage the power of Envoy to enhance the performance, scalability, and reliability of your applications running on AKS.
