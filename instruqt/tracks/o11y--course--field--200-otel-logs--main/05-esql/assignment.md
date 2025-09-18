---
slug: esql
id: dsowylbzjzkr
type: challenge
title: Life before attributes
notes:
- type: text
  contents: In this challenge, we will consider the challenges of working with limited
    context while performing Root Cause Analysis of a reported issue
tabs:
- id: 3gpgxqod4yll
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:60000),time:(from:now-15m,to:now))&_a=(columns:!(),dataSource:(dataViewId:'logs-*',type:dataView),filters:!(),hideChart:!f,interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))
  port: 30001
- id: yjuklc3tqqob
  title: VS Code
  type: service
  hostname: host-1
  path: ?folder=/workspace/workshop
  port: 8080
difficulty: ""
timelimit: 600
enhanced_loading: null
---

In many cases, you might be ok to parse your logs on-demand. As an example, i can use ES|QL to parse my nginx proxy logs as needed.

## ES|QL

Let's first try query-time parsing using ES|QL:

1. Open the [button label="Elasticsearch"](tab-1) tab
2. Click the 'Try ES|QL' button
3. Copy
    ```esql
    FROM logs-* | WHERE service.name == "trader" | GROK message """%{IP:client_address} - - \[%{GREEDYDATA:timestamp}\] \x22%{WORD:method} %{URIPATH:path}(?:%{URIPARAM:param})? %{WORD:protocol_name}/%{NUMBER:protocol_version}\x22 %{NUMBER:status_code} -""" | EVAL @timestamp = DATE_PARSE("dd/MMM/yyyy HH:mm:ss", timestamp) | WHERE status_code IS NOT NULL | KEEP @timestamp, timestamp
    ```
    into the `ES|QL` box
4. Click 'Run'

here, we've parsed

FROM logs-* | WHERE service.name == "trader" | GROK message """%{IP:client_address} - - \[%{GREEDYDATA:timestamp}\] \x22%{WORD:method} %{URIPATH:path}(?:%{URIPARAM:param})? %{WORD:protocol_name}/%{NUMBER:protocol_version}\x22 %{NUMBER:status_code} -""" | EVAL @timestamp = DATE_PARSE("dd/MMM/yyyy HH:mm:ss", timestamp) | WHERE status_code IS NOT NULL | KEEP @timestamp, timestamp

FROM logs-* | WHERE service.name == "trader" | GROK message """%{IP:client_address} - - \[%{GREEDYDATA:time}\] \x22%{WORD:method} %{URIPATH:path}(?:%{URIPARAM:param})? %{WORD:protocol_name}/%{NUMBER:protocol_version}\x22 %{NUMBER:status_code} -""" | WHERE status_code IS NOT NULL | STATS status = COUNT(status_code) BY status_code, method, path
