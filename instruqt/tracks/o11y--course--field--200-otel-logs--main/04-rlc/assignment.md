---
slug: rlc
id: cnxobswy9uyl
type: challenge
title: OpenTelemetry Logging with receiver creator
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
- id: fyb01yrpxc5q
  title: OTTL Playground
  type: website
  url: https://ottl.run/
- id: amxs2wbeu14y
  title: collector Config
  type: code
  hostname: host-1
  path: /workspace/workshop/collector/_courses/o11y--course--field--200-otel-logs--main/_challenges/04-rlc/values.patch
- id: im6htfxz8yft
  title: postgresql Config
  type: code
  hostname: host-1
  path: /workspace/workshop/k8s/yaml/postgresql.yaml
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

Modifying the collector config to parse specific logs feels awkward. it might make sense if most of your custom logs follow a common format, but typcially the format is unique and bespoke to specific apps. If your apps are deployed on k8s, we can use the RLC to move the parsing config to the app yaml rather than values.yaml.

Receiver Log Creator

look at postgres logs (no parse)



talk about SQL commentor. trace_id.

Do it with postgres logs.




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

Now let's redeploy the OTel Operator with our updated config:

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack --force \
  --namespace opentelemetry-operator-system \
  --values 'collector/values.yaml' \
  --version '0.9.1'
```