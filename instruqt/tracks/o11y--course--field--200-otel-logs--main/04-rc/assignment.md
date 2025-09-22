---
slug: rc
id: cnxobswy9uyl
type: challenge
title: OpenTelemetry Logging on Kubernetes with Receiver Creator
notes:
- type: text
  contents: In this challenge, we will look at how the Receiver Creator works
tabs:
- id: vgilav3kazur
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),query:(language:kuery,query:''),refreshInterval:(pause:!t,value:60000),time:(from:now-1h,to:now))&_a=(breakdownField:log.level,columns:!(),dataSource:(type:esql),filters:!(),hideChart:!f,interval:auto,query:(esql:'FROM%20logs-*%20%0A%7C%20WHERE%20service.name%20%3D%3D%20%22postgresql%22%0A%20%20'),sort:!(!('@timestamp',desc)))
  port: 30001
- id: ubyi9wpnvjzg
  title: Collector Config
  type: code
  hostname: host-1
  path: /workspace/workshop/collector/_courses/o11y--course--field--200-otel-logs--main/_challenges/04-rc/values.patch
- id: 6ebux7uxhpyo
  title: postgresql Config
  type: code
  hostname: host-1
  path: /workspace/workshop/k8s/yaml/postgresql.yaml
- id: 5luf3xjq6izp
  title: Terminal
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
difficulty: ""
timelimit: 600
lab_config:
  custom_layout: '{"root":{"children":[{"branch":{"size":67,"children":[{"leaf":{"tabs":["vgilav3kazur","ubyi9wpnvjzg","6ebux7uxhpyo"],"activeTabId":"vgilav3kazur","size":72}},{"leaf":{"tabs":["5luf3xjq6izp"],"activeTabId":"5luf3xjq6izp","size":25}}]}},{"leaf":{"tabs":["assignment"],"activeTabId":"assignment","size":31}}],"orientation":"Horizontal"}}'
enhanced_loading: null
---
Modifying the Collector config to parse specific logs feels awkward. Ideally, we would push bespoke parsing configurations to the deployment of the app or service itself. Realistically, it is the service which is in the best position to know the nuances of its custom logging pattern.

Fortunately, on Kubernetes, just such an option exists: the [Receiver Creator](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/receivercreator/README.md) can be used to dynamically instantiate `file` receivers with a custom configuration driven by the deployment yaml of each service.

it might make sense if most of your custom logs follow a common format, but typcially the format is unique and bespoke to specific apps. If your apps are deployed on k8s, we can use the Receiver Creator to move the parsing config to the app yaml rather than values.yaml.

Let's have a look at our postgresql logs.

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-*
| WHERE service.name == "postgresql"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Log overview` tab

Note the unstructured nature of these logs. One kind of neat aspect is the present of `traceparent` on some of the logs. Recall that these logs are generated from postgresql directly. Postgresql at present is not OpenTelemetry enabled, and thus has no native provisions for accepting a `traceparent` via distributed tracing. How did this line get there?

SQL Commentor. SQL comments is an extension (available for at least the Java language) which can append `traceparent`as a comment to SQL queries. Most databases (including postgresql) will output the comment as part of the audit log.

Let's parse these logs using the Receiver Creator.

Let's have a look at the Receiver Creator config
1. Open the [button label="Collector Config"](tab-1) tab



Now we need to modify our `postgresql.yaml` to include our directives.

1. Open the [button label="postgresql Config"](tab-2) tab
2. Search for the comment `# WORKSHOP CONTENT GOES HERE`
3. Replace it with the following:
```yaml
        io.opentelemetry.discovery.logs/config: |
          operators:
          - type: container
          - type: regex_parser
            on_error: send_quiet
            parse_from: body
            regex: '^(?P<timestamp_field>\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}.\d{3}\s[A-z]+)\s\[\d+\]\s(?P<severity_field>[A-Z]+):\s*(?<msg_field>.*?)\s*(\/\*traceparent=\x27(?P<version>\d*)?-(?P<trace_id>\S*)-(?P<span_id>\S*)-(?P<trace_flags>\d*)\x27\*\/)?$'
            timestamp:
              parse_from: attributes.timestamp_field
              on_error: send_quiet
              layout_type: strptime
              layout: '%Y-%m-%d %H:%M:%S.%L %Z'
            trace:
              trace_id:
                parse_from: attributes.trace_id
                on_error: send_quiet
              span_id:
                parse_from: attributes.span_id
                on_error: send_quiet
              trace_flags:
                parse_from: attributes.trace_flags
                on_error: send_quiet
            severity:
              parse_from: attributes.severity_field
              on_error: send_quiet
              mapping:
                warn:
                  - WARNING
                  - NOTICE
                error:
                  - ERROR
                info:
                  - LOG
                  - INFO
                  - STATEMENT
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
          - type: remove
            on_error: send_quiet
            field: attributes.trace_version
          - type: remove
            on_error: send_quiet
            field: attributes.trace_id
          - type: remove
            on_error: send_quiet
            field: attributes.span_id
          - type: remove
            on_error: send_quiet
            field: attributes.trace_flags
```

This blog applies a regex.



> [!NOTE]
> You note that Receiver Creator unfortunately uses a different language than OTTL. Notably, Receiver Creator does its transforms within the receiver itself, unlike OTTL which is instrumented using a Processor.

Now apply it:
1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
./deploy.sh -s postgresql
./deploy.sh -s recorder-java
```

Check Elasticsearch:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-* WHERE service.name == "postgresql"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Log overview` tab

Check logs:

1. Click `Applications` > `Service Inventory` in the left-hand navigation pane
2. Click on the `Service Map` tab
3. Click on the `trader` service
4. Click on `Service Details`
5. Click on the `Transactions` tab
6. Scroll down and click on the `POST /trade/request` transaction under `Transactions`
7. Scroll down to the waterfall graph under `Trace sample`
8. Click on the `Logs` tab
9. Click on the `execute <unnamed>: ...` log line emitted by the `postgresql` service
10. Click on the `Table` tab
11. Search for the attribute `trace.id`

Note how with SQL Commentor, OpenTelemetry, and Elastic, we can correlate our postgresql audit logs with our traces!
