---
slug: esql
id: dsowylbzjzkr
type: challenge
title: Using ES|QL to Parse OpenTelemetry Logs
notes:
- type: text
  contents: In this challenge, we will look at how to parse OpenTelemetry logs using
    ES|QL
tabs:
- id: 3gpgxqod4yll
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),query:(language:kuery,query:''),refreshInterval:(pause:!t,value:60000),time:(from:now-1h,to:now))&_a=(breakdownField:log.level,columns:!(),dataSource:(type:esql),filters:!(),hideChart:!f,interval:auto,query:(esql:'FROM%20logs-proxy.otel-default'),sort:!(!('@timestamp',desc)))
  port: 30001
difficulty: ""
timelimit: 600
enhanced_loading: null
---

In some cases, it might suffice to simply parse your logs on-demand rather than to do so at the edge. This is particularly beneficial to SREs who need to parse as part of a one-time Root Cause Analysis.

Elastic's ES|QL piped query language makes this really easy:

1. Open the [button label="Elasticsearch"](tab-1) tab
2. Execute the following query:
```esql
FROM logs-proxy.otel-default
| GROK body.text "%{IPORHOST:client_ip} %{USER:ident} %{USER:auth} \\[%{HTTPDATE:timestamp}\\] \"%{WORD:http_method} %{NOTSPACE:request_path} HTTP/%{NUMBER:http_version}\" %{NUMBER:status_code} %{NUMBER:body_bytes_sent:int} %{NUMBER:duration:float} \"%{DATA:referrer}\" \"%{DATA:user_agent}\"" // parse access log
| WHERE status_code IS NOT NULL
| EVAL @timestamp = DATE_PARSE("dd/MMM/yyyy:HH:mm:ss Z", timestamp) // use embedded timestamp as record timestamp
| KEEP @timestamp, client_ip, http_method, request_path, status_code, user_agent
```
