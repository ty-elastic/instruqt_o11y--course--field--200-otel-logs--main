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

Parsing w/ ESQL


Making Sense of JSON Logs
===

Many custom applications log to a JSON format to provide some structure to the log line. To fully appreciate this benefit in a logging backend, however, you need to parse that JSON (embedded in the log line) and extract fields fo interest. Historically, we've done this in Elastic using Ingest Pipelines. Notably, as of 8.18.0/9.0, Ingest Pipelines cannot be used to parse

1. [button label="Elastic"](tab-0)
2. Observability > Discover
3. Query for `router` service logs:
```kql
service.name : "router"
````
4. Look at `body.text` field (it is encoded JSON)

## JSON Parsing in the Collector
Get a copy of the latest values.yaml
1. [button label="Elastic"](tab-0)
2. Click `Add data` in lower-left
3. Click `Kubernetes` > `OpenTelemetry (Full Observability)`
4. Copy the URL to the `values.yaml`
```
https://raw.githubusercontent.com/elastic/elastic-agent/refs/tags/v8.17.4/deploy/helm/edot-collector/kube-stack/values.yaml
```
7. [button label="Terminal"](tab-1)
8. Download it with `curl`
```bash,run
cd collector
curl -o values.yaml https://raw.githubusercontent.com/elastic/elastic-agent/refs/tags/v8.17.4/deploy/helm/edot-collector/kube-stack/values.yaml
```
8. [button label="Code"](tab-2)
9. Click refresh
10. Add an OTTL parser for JSON:
under `collectors` > `daemon` > `config` > `processors` add the following:
```ottl
      processors:

        transform/parse_json_body:
            error_mode: ignore
            log_statements:
              - context: log
                conditions:
                  - body != nil and Substring(body, 0, 2) == "{\""
                statements:
                  - set(cache, ParseJSON(body))
                  - flatten(cache, "")
                  - merge_maps(attributes, cache, "upsert")

                  - set(time, Time(attributes["_meta.date"], "%Y-%m-%dT%H:%M:%SZ"))
                  - delete_key(log.attributes, "_meta.date")

                  - set(severity_text, attributes["_meta.logLevelName"])
                  - set(severity_number, attributes["_meta.logLevelId"])
                  - delete_key(log.attributes, "_meta.logLevelName")
                  - delete_key(log.attributes, "_meta.logLevelId")

                  - set(body, attributes["0"])
                  - delete_key(log.attributes, "0")
```
10. add it into log pipelines:
under `collectors` > `daemon` > `config` > `service` > `pipelines` > `logs/node` > `processors` add `transform/parse_json_body`:
```
processors:
              - transform/parse_json_body
              ...
```
under `collectors` > `daemon` > `config` > `service` > `pipelines` > `logs/apm` > `processors` add `transform/parse_json_body`:
```
processors:
              - transform/parse_json_body
              ...
```
11. reload the operator with load values.yaml
12. [button label="Terminal"](tab-1)
```bash,run
helm uninstall opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack --namespace opentelemetry-operator-system

sleep 15

helm install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
  --namespace opentelemetry-operator-system \
  --values values.yaml \
  --version '0.3.3'

sleep 15

kubectl rollout restart deployment -n k8sotel
```

## JSON Logs
1. [button label="Elastic"](tab-0)
2. Hamburger menu > Logs
3. Query for `router` service logs:
```kql
service.name : "router"
````
4. Look at `body.text` field (it is no longer json encoding, but rather displays what was formally in `message`)


Parsing
===

It is worth noting that OpenTelemetry generally advocates for edge vs. centralized log parsing. This is a notable change from how we've historically handled log parsing. Conceptually, pushing log parsing as close to the edge should ultimately make the parsing more robust; as you make changes at the edges of your system (e.g., upgrading the version of a deployed service), you can, in lock step, update applicable log parsing rules.

We are going to look at 3 different ways to parse log lines:
1) query-time via ES|QL
2) centralized with Elasticsearch Streams (in Tech Preview)
3) edge with OTTL

Our `trader` service leverages the Flask framework. While we can control the format of the log lines pushed via stdout from our Python code, the Flask framework generates log lines in its own Apache-like format.

Let's look at those lines:

3. Open the [button label="Elasticsearch"](tab-1) tab
4. Copy
    ```kql
    service.name: "trader"
    ```
    into the `Filter your data using KQL syntax` search bar toward the top of the Kibana window

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
## OTTL


## Elasticsearch Streans

dd/MMM/yyyy HH:mm:ss



Ideally, we want timestamps and log level as first class citizens.

1. Open the [button label="VSCode"](tab-2) tab
2. Open `k8s/postgresql.yaml`
3. Add the following annotation under `spec/template/metadata` (should be same level as `labels`):
  ```yaml
        annotations:
        io.opentelemetry.discovery.logs.postgresql/enabled: "true"
        io.opentelemetry.discovery.logs.postgresql/config: |
          operators:
          - type: container
          - type: regex_parser
            on_error: send
            parse_from: body
            regex: '^(?P<timestamp_field>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3} [A-z]+)\s\[\d{2}\]\s(?P<severity_field>[A-Z]+):\s*(?<msg_field>.*)$'
            timestamp:
              parse_from: attributes.timestamp_field
              on_error: send
              layout_type: strptime
              layout: '%Y-%m-%d %H:%M:%S.%L %Z'
          - type: severity_parser
            parse_from: attributes.severity_field
            on_error: send
            mapping:
              warn:
                - WARNING
                - NOTICE
              error:
                - ERROR
              info:
                - LOG
                - INFO
              debug1:
                - DEBUG1
              debug2:
                - DEBUG2
              debug3:
                - DEBUG3
              debug4:
                - DEBUG4
              debug5:
                - DEBUG5
              fatal:
                - FATAL
                - PANIC
          - type: move
            on_error: send_quiet
            from: attributes.msg_field
            to: body
          - type: remove
            on_error: send_quiet
            field: attributes.timestamp_field
          - type: remove
            on_error: send_quiet
            field: attributes.severity_field
  ```
4. apply our modified deployment yaml:
  ```
  ./install.sh
  ```

Now let's look at our results:
1. Open the [button label="Elasticsearch"](tab-1) tab
2. Copy
    ```kql
    service.name: "postgresql"
    ```
    into the `Filter your data using KQL syntax` search bar toward the top of the Kibana window
3. Click on the refresh icon at the right of the time picker
4. Note that we now have a log level!
5. Open a log message... note that the @timestamp is set correctly, and we've stripped the header from body.text

# Experimenting with SQL Commenter
