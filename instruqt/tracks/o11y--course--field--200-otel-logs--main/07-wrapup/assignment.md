---
slug: wrapup
type: challenge
title: Wrapping Up
notes:
- type: text
  contents: In this challenge, we summarize our work in this lab.
tabs:
- id: v4zr50caye11
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:60000),time:(from:now-15m,to:now))&_a=(columns:!(),dataSource:(dataViewId:'logs-*',type:dataView),filters:!(),hideChart:!f,interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))
  port: 30001
difficulty: ""
timelimit: 600
enhanced_loading: null
---
In this lab, we presented several different ways of capturing and parsing logs using OpenTelemetry.

In reality, you will likely use a combination of these techniques, depending on your system:

* you might use OTLP for greenfield applications
* you might use Receiver Creator for k8s applications
* you might use file receiver for VMs

* you might rely on ES|QL parsing for on-demand parsing
* for permanent parsing, you might use edge parsing for well-known log formats (postgresql), but rely on Streams for more flexible formats (custom apps)
