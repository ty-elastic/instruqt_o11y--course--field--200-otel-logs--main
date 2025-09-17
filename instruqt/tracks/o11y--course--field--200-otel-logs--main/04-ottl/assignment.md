---
slug: ottl
id: ahmyfvb4yziz
type: challenge
title: Life before attributes
notes:
- type: text
  contents: In this challenge, we will consider the challenges of working with limited
    context while performing Root Cause Analysis of a reported issue
tabs:
- id: dekcztd9nux2
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:60000),time:(from:now-15m,to:now))&_a=(columns:!(),dataSource:(dataViewId:'logs-*',type:dataView),filters:!(),hideChart:!f,interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))
  port: 30001
- id: 1vkc4xk5xxzv
  title: VS Code
  type: service
  hostname: host-1
  path: ?folder=/workspace/workshop
  port: 8080
difficulty: ""
timelimit: 600
enhanced_loading: null
---

SQL commentor


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
