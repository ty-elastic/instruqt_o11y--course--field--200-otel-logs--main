---
slug: file
id: co1ozkck8zux
type: challenge
title: Life before attributes
notes:
- type: text
  contents: In this challenge, we will consider the challenges of working with limited
    context while performing Root Cause Analysis of a reported issue
tabs:
- id: jeu1estyxf1z
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),query:(language:kuery,query:''),refreshInterval:(pause:!t,value:60000),time:(from:now-1h,to:now))&_a=(breakdownField:log.level,columns:!(),dataSource:(type:esql),filters:!(),hideChart:!f,interval:auto,query:(esql:'FROM%20logs-*%20%0A%7C%20WHERE%20service.name%20%3D%3D%20%22router%22%0A%20%20'),sort:!(!('@timestamp',desc)))
  port: 30001
- id: kr5jkc770z5f
  title: collector Config
  type: code
  hostname: host-1
  path: /workspace/workshop/collector/_courses/o11y--course--field--200-otel-logs--main/_challenges/03-file
- id: 4qcxxz95lkpr
  title: router Source
  type: code
  hostname: host-1
  path: /workspace/workshop/src/router
- id: lyqrwsofywhh
  title: Terminal
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
difficulty: ""
timelimit: 600
lab_config:
  custom_layout: '{"root":{"children":[{"branch":{"size":67,"children":[{"leaf":{"tabs":["jeu1estyxf1z","kr5jkc770z5f","4qcxxz95lkpr"],"activeTabId":"jeu1estyxf1z","size":38}},{"leaf":{"tabs":["lyqrwsofywhh"],"activeTabId":"lyqrwsofywhh","size":60}}]}},{"leaf":{"tabs":["assignment"],"activeTabId":"assignment","size":32}}],"orientation":"Horizontal"}}'
enhanced_loading: null
---
As noted, there are many reasons why use of OTLP logging may be impractical. Chief among them is accommodating services which cannot be instrumented with OpenTelemetry (e.g., third-party services). These services simply write their logs to disk directly, or more commonly to stdout, which is then written to disk by the Kubernetes or Docker logging framework, for example. 

To accommodate such services, we can use the [filelog receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver) in the OTel Collector. In many regards, the `filelog` receiver is the OTel equivalent of Elastic's filebeat (often running as a module inside Elastic Agent).

In this example, we will be working with a service which outputs logs to stdout in a custom JSON format.

Now let's see what our logs look like in Elasticsearch.
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-* WHERE service.name == "router"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Log overview` tab

Note that the body of the message is JSON-formatted.

# Checking the Source

Now let's validate that these logs are being emitted to stdout, and written to disk:

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following to get a list of the active Kubernetes pods that comprise our trading system:
```bash,run
kubectl -n trading get pods
```
3. Find the active `router-...` pod in the list
4. Get stdout logs from the active `router` pod:
```bash,nocopy
kubectl -n trading logs <router-...>
```
(replace ... with the pod instance id)

Note that logs are written to stdout.

Now let's validate that Kubernetes is picking up stdout and written to disk:

1. Open the [button label="Terminal"](tab-3) tab
2. Let's peek on the logs being written to disk by Kubernetes
```bash,run
cd /var/log/pods/
ls
```
3. Get logs for current instant of the `router` pod
```bash,run
cd trading_router*
ls
cd router
```
4. Look at the logs:
```bash,run
cat 0.log
```

Making Sense of JSON Logs
===
Many custom applications log to a JSON format to provide some structure to the log line. To fully appreciate this benefit in a logging backend, however, you need to parse that JSON (embedded in the log line) and extract fields fo interest. 

While you could do this with Elasticsearch using Streams (as we will see in the future challenge), with OpenTelemetry, this can also be done in the Collector using [OTTL](https://opentelemetry.io/docs/collector/transforming-telemetry/).


4. Get stdout logs from the active `router` pod:
```bash,nocopy
kubectl -n trading logs <router-...>
```
/var/log/pods/



Let's first look at a service that is writing logs to disk.
kubectl get pods
kubectl logs router

clearly stdout.

check elastic.


show OTTL processor

Like Filebeat or logstash, you can do some parsing of logs at the edge.

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

We are using the OTel Operator with a stock config provided by Elastic to insert instrumentation into our applications. To start parsing JSON logs, we will need to modify that configuration.

Let's first get a copy of the values.yaml.

Get a copy of the latest values.yaml
1. [button label="Elastic"](tab-0)
2. Click `Add data` in lower-left
3. Click `Kubernetes` > `OpenTelemetry (Full Observability)`
4. Copy the URL to the `values.yaml`
```
https://raw.githubusercontent.com/elastic/elastic-agent/refs/tags/v9.1.3/deploy/helm/edot-collector/kube-stack/values.yaml
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


ADD structured logging
- fix metadata
- fix struc logging