---
slug: file
id: co1ozkck8zux
type: challenge
title: OpenTelemetry Logging with the Filelog Receiver
notes:
- type: text
  contents: In this challenge, we will look at how the Filelog Receiver works
tabs:
- id: t3tg2slqodjt
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),query:(language:kuery,query:''),refreshInterval:(pause:!t,value:60000),time:(from:now-1h,to:now))&_a=(breakdownField:log.level,columns:!(),dataSource:(type:esql),filters:!(),hideChart:!f,interval:auto,query:(esql:'FROM%20logs-*%20%0A%7C%20WHERE%20service.name%20%3D%3D%20%22router%22%0A%20%20'),sort:!(!('@timestamp',desc)))
  port: 30001
- id: fyb01yrpxc5q
  title: OTTL Playground
  type: website
  url: https://ottl.run/
- id: amxs2wbeu14y
  title: Collector Config
  type: code
  hostname: host-1
  path: /workspace/workshop/collector/values.yaml
- id: im6htfxz8yft
  title: router Source
  type: code
  hostname: host-1
  path: /workspace/workshop/src/router
- id: gquoynyprmua
  title: Terminal
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
difficulty: ""
timelimit: 600
lab_config:
  custom_layout: '{"root":{"children":[{"branch":{"size":67,"children":[{"leaf":{"tabs":["t3tg2slqodjt","fyb01yrpxc5q","amxs2wbeu14y","im6htfxz8yft"],"activeTabId":"t3tg2slqodjt","size":82}},{"leaf":{"tabs":["gquoynyprmua"],"activeTabId":"gquoynyprmua","size":15}}]}},{"leaf":{"tabs":["assignment"],"activeTabId":"assignment","size":31}}],"orientation":"Horizontal"}}'
enhanced_loading: null
---
There are many reasons why use of OTLP-based logging may be impractical. Chief among them is accommodating services which cannot be instrumented with OpenTelemetry (e.g., third-party services). These services simply write their logs to disk directly, or more commonly to stdout, which is then written to disk by the Kubernetes or Docker logging provider, for example.

To accommodate such services, we can use the [filelog receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver) in the OTel Collector. In many regards, the `filelog` receiver is the OTel equivalent of Elastic's filebeat (often running as a module inside Elastic Agent).

![method-2](../assets/method2.mmd.png)

Getting our bearings
===
In this example, we will be working with a service which outputs logs to stdout in a custom JSON format.

Let's first examine the raw JSON logs as they are currently being received by Elasticsearch:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Execute the following query:
```esql
FROM logs-*
| WHERE service.name == "router"
```
3. Open the first log record by clicking on the double arrow icon under `Actions`
4. Click on the `Log overview` tab

Note that the body of the message is not particularly useable:
* it has a "burned-in" JSON format
* it contains both the message ("0") and associated metadata ("_meta")
* the log level as presented by Elasticsearch will always be `INFO` regardless of the actual log level

# Checking the Source
Now let's validate that these logs are indeed being emitted to stdout and written to disk:

1. Open the [button label="Terminal"](tab-4) tab
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

Note that the logs are being written to stdout and are being captured by the Kubernetes logging provider. Let's validate that Kubernetes is writing this log stream to disk:

1. Open the [button label="Terminal"](tab-4) tab
2. Get all log files associated with pods
```bash,run
cd /var/log/pods/
ls
```
3. Get logs for current instant of the `router` pod
```bash,run
cd trading_router*
ls
cd router
ls
```
4. Look at the router container logs
```bash,run
cat 0.log
```

Yup! Clearly these logs are being written to disk.

Parsing JSON logs
===
Many custom applications log to a JSON format to provide some structure to the log line. To fully appreciate this benefit in a logging backend, however, you need to parse that JSON (embedded in the log line) and extract fields of interest.

While you could do this with Elasticsearch using Streams (as we will see in the future challenge), with OpenTelemetry, this can also be done at the edge in the Collector using [OTTL](https://opentelemetry.io/docs/collector/transforming-telemetry/).

# OTTL Playground
Crafting OTTL in a vacuum is tricky: the feedback loop of crafting OTTL, deploying it to the collector, validating it has the correct syntax, and validating it does what you expect can be long and painful.

Fortunately, there is a better way! Elastic has made available the [OTTL Playground](https://ottl.run): a tool to interactively refine your OTTL before putting it in production.

1. Open the [button label="OTTL Playground"](tab-1) tab
2. Paste into the `OTLP Payload` pane an example from our JSON formatted `router` logs:
```json
{
  "resourceLogs": [
    {
      "resource": {},
      "scopeLogs": [
        {
          "scope": {},
          "logRecords": [
            {
              "timeUnixNano": "1544712660300000000",
              "observedTimeUnixNano": "1544712660300000000",
              "severityNumber": 10,
              "severityText": "Information",
              "traceId": "5b8efff798038103d269b633813fc60c",
              "spanId": "eee19b7ec3c1b174",
              "body": {
                "stringValue": "{\"0\": \"routing request to http://recorder-java:9003\",  \"_meta\": {    \"runtime\": \"Nodejs\",    \"runtimeVersion\": \"v20.19.5\",    \"hostname\": \"router-689cd9bd99-khtfx\",    \"name\": \"router\",    \"parentNames\": \"[undefined]\",    \"date\": \"2025-09-20T11:59:59.741Z\",    \"logLevelId\": 3,    \"logLevelName\": \"INFO\",    \"path\": {      \"fullFilePath\": \"/home/node/app/app.ts:35:10\",      \"fileName\": \"app.ts\",      \"fileNameWithLine\": \"app.ts:35\",      \"fileColumn\": \"10\",      \"fileLine\": \"35\",      \"filePath\": \"/app.ts\",      \"filePathWithLine\": \"/app.ts:35\",      \"method\": \"customRouter\"    }  }}"
              }
            }
          ]
        }
      ]
    }
  ]
}
```
3. Paste into the `Configuration` pane the following:
```yaml
            log_statements:
              - context: log
                conditions:
                  - body != nil and Substring(body, 0, 2) == "{\""
                statements:
                  - set(cache, ParseJSON(body))
                  - flatten(cache, "")
                  - merge_maps(attributes, cache, "upsert")
```

Those initial set of log statements:
1. check if the message body is JSON formatted
2. if so, parses the body as json, flattens the key names (to prevent nesting), and merges all extracted keys to `attributes`

Click on the `Run >` button. In the `Result` pane, you can see the diff of what this OTTL would do, and it _kind of_ matches what we expect.

It is far from ideal:
* it does not conform to OTel semantic conventions (e.g., `_meta.logLevelName`, `_meta.date`)
* the message body is stored as an attribute with key `0`

Let's clean that up with OTTL!

1. Paste the following into the `Configuration` pane:
```yaml
            log_statements:
              - context: log
                conditions:
                  - body != nil and Substring(body, 0, 2) == "{\""
                statements:
                  - set(cache, ParseJSON(body))
                  - flatten(cache, "")
                  - merge_maps(attributes, cache, "upsert")

                  - set(time, Time(attributes["_meta.date"], "%Y-%m-%dT%H:%M:%SZ"))
                  - set(severity_text, attributes["_meta.logLevelName"])
                  - set(severity_number, Int(attributes["_meta.logLevelId"]))
                  - delete_matching_keys(attributes, "_meta\\..*")

                  - set(body, attributes["0"])
                  - delete_key(attributes, "0")
```
2. Click on the `Run >` button

Ah, that looks much better! Here, we are:
* converting the date from a string to an epoch timestamp and copying it into the proper semantic convention (semcon) field
* copy the log level into the proper semcon fields
* deleting the remaining `_meta.*` fields
* copying the body from `attributes.0` to the proper semcon field
* deleting the now defunct `attributes.0`

This looks great. Let's put this configuration into production!

# Putting It Into Production

1. Open the [button label="Collector Config"](tab-2) tab
2. Open the file `values.yaml`
3. Find the following block under `collectors/daemon/config/processors`:
```yaml,nocopy
        # REPLACE THIS BLOCK WITH WORKSHOP CONTENT
        transform/parse_json_body:
            error_mode: ignore
```
4. Replace it with the OTTL we developed above:
```yaml
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
                  - set(severity_text, attributes["_meta.logLevelName"])
                  - set(severity_number, Int(attributes["_meta.logLevelId"]))
                  - delete_matching_keys(attributes, "_meta\\..*")

                  - set(body, attributes["0"])
                  - delete_key(attributes, "0")
```

Now let's redeploy the OTel Operator with our updated config:

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
cd /workspace/workshop
helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack --force \
  --namespace opentelemetry-operator-system \
  --values 'collector/values.yaml' \
  --version '0.10.5'
```

This will redeploy the OTelOperator, which in turn will restart the daemonset Collectors with their new config. We can check when the new configuration has taken affect by looking at the status of the daemonset Collectors.

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
kubectl -n opentelemetry-operator-system get pods
```

When you see that the replacement daemonset Collectors have been up for at least 30 seconds, let's check the logs coming into Elastic:

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-*
| WHERE service.name == "router"
| WHERE message LIKE "routing request*"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Log overview` tab

> [!NOTE]
> you may have to refresh the ES|QL query several times before results are present

Yes! Note that cleanly parsed JSON logs:
* the message body is now just the message
* the log level and timestamp are set correctly

Nice and clean JSON logs in Elastic: perfect.

Well almost. You'll note that we had to modify the configuration of the Collector in the daemonset; the same Collector which handles logs from all of our services. Imagine we have multiple services, each which outputs a unique JSON schema. In that case, we would have to introduce routing in our Collector pipelines in order to selectively apply the right OTTL for a given log source... What if there was a way that the services themselves could specify their configuration?
