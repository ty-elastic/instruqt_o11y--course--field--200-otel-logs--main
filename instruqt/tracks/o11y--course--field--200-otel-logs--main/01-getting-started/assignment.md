---
slug: getting-started
id: izlqqkzxglpx
type: challenge
title: Getting Started
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
The advent of [OpenTelemetry](https://opentelemetry.io) has forever changed how we capture observability signals. While OTel initially focused on delivering traces and metrics, support for collection of logs is now stable and gaining adoption, particularly in Kubernetes environments.

In this lab, we will explore several models for using OpenTelemetry to collect and parse logs.

# Lab Architecture

In this lab, we will be working with an exemplary stock trading system, comprised of several services and their dependencies running in Kubernetes. We are using the OpenTelemetry Operator to automatically instrument all of our services.

Our trading system is comprised of:

* `proxy`: a nginx reverse proxy which proxies requests from the outside into the trading system
* `trader`: a python application that trades stocks on orders from customers
* `router`: a node.js application that routes committed trade records
* `recorder-java`: a Java application that records trades to a PostgreSQL database

Finally, we have `monkey`, a python application we use for testing our system that makes periodic, automated trade requests on behalf of fictional customers. `monkey` routes its requests through `proxy`.
