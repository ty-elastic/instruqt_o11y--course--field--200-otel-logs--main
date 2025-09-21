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
- id: t3tg2slqodjt
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),query:(language:kuery,query:''),refreshInterval:(pause:!t,value:60000),time:(from:now-1h,to:now))&_a=(breakdownField:log.level,columns:!(),dataSource:(type:esql),filters:!(),hideChart:!f,interval:auto,query:(esql:'FROM%20logs-*%20%0A%7C%20WHERE%20service.name%20%3D%3D%20%22router%22%0A%20%20'),sort:!(!('@timestamp',desc)))
  port: 30001
- id: 7gj58ylskiig
  title: OTTL Playground
  type: website
  url: https://ottl.run/
- id: amxs2wbeu14y
  title: collector Config
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
  custom_layout: '{"root":{"children":[{"branch":{"size":67,"children":[{"leaf":{"tabs":["jeu1estyxf1z","kr5jkc770z5f","4qcxxz95lkpr"],"activeTabId":"jeu1estyxf1z","size":38}},{"leaf":{"tabs":["lyqrwsofywhh"],"activeTabId":"lyqrwsofywhh","size":60}}]}},{"leaf":{"tabs":["assignment"],"activeTabId":"assignment","size":32}}],"orientation":"Horizontal"}}'
enhanced_loading: null
---
As noted, there are many reasons why use of OTLP logging may be impractical. Chief among them is accommodating services which cannot be instrumented with OpenTelemetry (e.g., third-party services). These services simply write their logs to disk directly, or more commonly to stdout, which is then written to disk by the Kubernetes or Docker logging framework, for example.

To accommodate such services, we can use the [filelog receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver) in the OTel Collector. In many regards, the `filelog` receiver is the OTel equivalent of Elastic's filebeat (often running as a module inside Elastic Agent).

![method-2](../assets/method2.mmd.png)

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

Note that logs are written to stdout.

Now let's validate that Kubernetes is picking up stdout and written to disk:

1. Open the [button label="Terminal"](tab-4) tab
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

# OTTL Playground

It is pretty tricky to craft OTTL in your Collector config, test, possibly fail, and fix. Fortunately, Elastic has made a great tool to let you interactively refine your OTTL before putting it in production.

1. Open the [button label="OTTL Playground"](tab-1) tab
2. Paste into the `OTLP Payload` pane an example of our JSON-ified `router` logs:
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
3. Pase into the `Configuration` pane the following starter configuration:
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
1. checks if the message body is JSON formatted
2. if so, parses the body as json, flattens the key names (to prevent nesting), and merges the results to `attributes`

Click on the `Run >` button. In the `Result` pane, you can see the diff of what this OTTL would do, and it kind of matches what we expect. 

It is far from ideal:
* it does not conform to OTel semantic conventions (e.g., `_meta.logLevelName`, `_meta.date`)
* the message body is now stored as an attribute with key `0`

Let's clean that up. 
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
                  - set(severity_number, attributes["_meta.logLevelId"])
                  - delete_matching_keys(attributes, "_meta\\..*")

                  - set(body, attributes["0"])
                  - delete_key(attributes, "0")
```
2. Click on the `Run >` button

Ah, that looks better. We:
* converted the date from a string to an epoch timestamp and copied it into the proper field
* copied the log level into the proper fields
* deleted the remaining `_meta.*` fields
* copied the body from `attributes.0` to the proper field
* deleted the body from `attributes.0`

This looks great. Let's put it into production!

# Modifying values.yaml

1. Open the [button label="collector Config"](tab-2) tab
2. Search for the comment `# WORKSHOP CONTENT GOES HERE`
3. Replace it with the OTTL we developed above:
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
                  - set(severity_number, attributes["_meta.logLevelId"])
                  - delete_matching_keys(attributes, "_meta\\..*")

                  - set(body, attributes["0"])
                  - delete_key(attributes, "0")
```

Now let's redeploy the OTel Operator with our updated config:

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack --force \
  --namespace opentelemetry-operator-system \
  --values 'collector/values.yaml' \
  --version '0.9.1'
```

Wait for a minute or so. We can check when the config has taken affect by looking for the daemonset collectors to restart.

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
kubectl -n opentelemetry-operator-system get pods
```

Once the daemonset collectors have restarted, let's check the logs coming into Elastic:

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-* WHERE service.name == "router"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Log overview` tab

Note the parsed JSON logs.

Let's do structured logging
===

1. Open the [button label="router Source"](tab-2) tab
2. Navigate to `app.ts`
3. Find the line in the function `customRouter()`
```ts
logger.info(`routing request to ${host}`);
```
4. Modify it to 
```ts
logger.info(`routing request to ${host}`, {method: method});
```

Now let's recompile and redeploy our `router` service.
1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
./builddeploy.sh -s router
```

Now let's see how that looks in Elasticsearch:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-* WHERE service.name == "router"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Log overview` tab

ugh, `1.method` is ugly. Let's fix it!

1. Open the [button label="OTTL Playground"](tab-1) tab
2. Pase into the `Configuration` pane the following starter configuration:
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
                  - set(severity_number, attributes["_meta.logLevelId"])
                  - delete_matching_keys(attributes, "_meta\\..*")

                  - set(body, attributes["0"])
                  - delete_key(attributes, "0")

                  - replace_all_patterns(attributes, "key", "\\d+\\.", "")
```

Note the addition of `replace_all_patterns(attributes, "key", "\\d+\\.", "")` which will remove the numerical prefix from attributes.


Now let's redeploy the OTel Operator with our updated config:

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack --force \
  --namespace opentelemetry-operator-system \
  --values 'collector/values.yaml' \
  --version '0.9.1'
```

Wait for a minute or so. We can check when the config has taken affect by looking for the daemonset collectors to restart.

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
kubectl -n opentelemetry-operator-system get pods
```

Now let's see how that looks in Elasticsearch:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-* WHERE service.name == "router"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Log overview` tab

Yeah! we've parsed our JSON logs!