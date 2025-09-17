---
slug: getting-our-bearings
id: izlqqkzxglpx
type: challenge
title: Getting our bearings
tabs:
- id: u2nmw20sfz6j
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
difficulty: basic
timelimit: 600
enhanced_loading: null
---
The advent of OpenTelemetry has forever changed how we capture observability signals. While OTel initially focused on delivering traces and metrics, support for collection of logs is now stable and gaining adoption, particularly in Kubernetes environments.

In this lab, we will explore several models for using OpenTelemetry to collect log signals:

1) Service to Collector via OTLP

In this model, we forgo log files entirely, routing log messages directly via the network (OTLP) from services to a Collector.
![service-map.png](../assets/method1.svg)

2) Service to Collector via log files formatted with OTel Semantic Conventions (`otlpjson`)

In this model, we output logs from services to a log file written with OTel Semantic Conventions (`otlpjson`), which we then collect via a Collector.
![service-map.png](../assets/method2.svg)

3) Service to Collector via arbitrarily formatted log files

In this model, we output logs from select services to a log file written in an arbitrary format, which we then collect via a Collector.
![service-map.png](../assets/method3.svg)

Additionally, for each model considered, we discuss how to add attributes to log messages and how to parse logs (both at the edge and in Elastic).

Getting Our Bearings
===

In this lab, we will be working with an exemplary stock trading system, comprised of several services and their dependencies, all instrumented using [OpenTelemetry](https://opentelemetry.io).

We will be working with a live Elasticsearch instance, displayed in the browser tab to the left. We are currently looking at Elastic's dynamically generated Service Map. It shows all of the services that comprise our system, and how they interact with one another.

![service-map](../assets/service-map.png)

Our trading system is composed of:
* `trader`: a python application that trades stocks on orders from customers
* `router`: a node.js application that routes committed trade records
* `recorder-java`: a Java application that records trades to a PostgreSQL database
* `notifier`: a .NET application that notifies an external system of completed trades

Finally, we have `monkey`, a python application we use for testing our system that makes periodic, automated trade requests on behalf of fictional customers.

> [!NOTE]
> You are welcome to explore each service and our APM solution by clicking on each service icon in the Service Map and selecting `Service Details`

When you are ready, click the `Next` button to continue.
