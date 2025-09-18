---
slug: streams
id: i6ixclinxgoc
type: challenge
title: Life before attributes
notes:
- type: text
  contents: In this challenge, we will consider the challenges of working with limited
    context while performing Root Cause Analysis of a reported issue
tabs:
- id: v4zr50caye11
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:60000),time:(from:now-15m,to:now))&_a=(columns:!(),dataSource:(dataViewId:'logs-*',type:dataView),filters:!(),hideChart:!f,interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))
  port: 30001
- id: psjerhfnv5n3
  title: VS Code
  type: service
  hostname: host-1
  path: ?folder=/workspace/workshop
  port: 8080
difficulty: ""
timelimit: 600
enhanced_loading: null
---

So far, we've been using ES|QL to parse our proxy logs at query-time. While incredibly powerful for quick analysis, we can do even more with our logs if we parse them at ingest-time.

# Parsing with Streams

We will be working with Elastic [Streams](https://www.elastic.co/docs/solutions/observability/logs/streams/streams) which makes it easy to setup log parsing pipelines.

1. Select `logs-proxy.otel-default` from the list of data streams (if you start typing, Elasticsearch will help you find it)
2. Select the `Processing` tab


## Parsing the log message

We can parse our nginx log messages at ingest-time using the Elastic [Grok](https://www.elastic.co/docs/reference/enrich-processor/grok-processor) processor.

1. Click `Add a processor`
2. Select the `Grok` Processor (if not already selected)
3. Set the `Field` to
  ```
  body.text
  ```
4. Click `Generate pattern`. Elasticsearch will analyze your log lines and try to determine a suitable grok pattern.
5. To ensure a consistent lab experience, copy the following grok expression and paste it into the `Grok patterns` field (_do not_ click the `Accept` button next to the generated pattern)
```
%{IPV4:client.ip} - %{NOTSPACE:client.user} \[%{HTTPDATE:timestamp}\] "%{WORD:http.request.method} %{URIPATH:http.request.url.path} HTTP/%{NUMBER:http.version}" %{NUMBER:http.response.status_code:int} %{NUMBER:http.response.body.bytes:int} "%{DATA:http.request.referrer}" "%{GREEDYDATA:user_agent.original}"
```
6. Wait until the sample `body.text` on the right shows highlighting, then click `Add processor`


## Parsing the timestamp

The nginx log line includes a timestamp; let's use that as our record timestamp.

1. Click `Add a processor`
2. Select `Date`
3. Set `Field` to `timestamp`
4. Elastic should auto-recognize the format: `dd/MMM/yyyy:HH:mm:ss XX`
5. Click `Add processor`


Now save the Processing by clicking `Save changes` in the bottom-right.

# A faster way to query

Now let's jump back to Discover by clicking `Discover` in the left-hand navigation pane.

Execute the following query:
```esql
FROM logs-proxy.otel-default
| WHERE http.response.status_code IS NOT NULL
| KEEP @timestamp, client.ip, http.request.method, http.request.url.path, http.response.status_code, user_agent.original
```

> [!NOTE]
> If you get back `1,000 results` but the resulting columns are empty, remove the `Selected fields` (by clicking the `X` next to each), and then add each `Available field` (by clicking the `+` next to each).

Let's redraw our status code graph using our newly parsed field:

Execute the following query:
```esql
FROM logs-proxy.otel-default
| WHERE http.response.status_code IS NOT NULL
| STATS COUNT() BY TO_STRING(http.response.status_code), minute = BUCKET(@timestamp, "1 min")
```

Note that this graph, unlike the one we drew before, currently shows only a few minutes of data. That is because it relies upon the fields we parsed in the Processing we just setup. Prior to that time, those fields didn't exist. Change the time field to `Last 5 Minutes` to zoom in on the newly parsed data.

