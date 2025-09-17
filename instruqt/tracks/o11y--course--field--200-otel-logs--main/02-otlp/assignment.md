---
slug: otlp
id: 0xjtiwwhgb8h
type: challenge
title: OpenTelemetry Logging with OTLP
notes:
- type: text
  contents: In this challenge, we will consider the challenges of working with limited
    context while performing Root Cause Analysis of a reported issue
tabs:
- id: jeu1estyxf1z
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:60000),time:(from:now-15m,to:now))&_a=(columns:!(),dataSource:(dataViewId:'logs-*',type:dataView),filters:!(),hideChart:!f,interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))
  port: 30001
- id: v5qkmu4br29y
  title: VS Code
  type: service
  hostname: host-1
  path: ?folder=/workspace/workshop
  port: 8080
difficulty: ""
timelimit: 600
enhanced_loading: null
---

In this model, we will be sending logs directly from a service to an OpenTelemetry [Collector](https://opentelemetry.io/docs/collector/) over the network using the [OTLP](https://opentelemetry.io/docs/specs/otel/protocol/) protocol. This is the default mechanism the OpenTelemetry SDKs use for exporting logs from a service.

![method-1](../assets/method1.svg)

Looking at the diagram:
1) A service leverages an existing logging framework (e.g., [logback](https://logback.qos.ch) in Java) to generate log statements
2) On startup, the OTel SDK injects a new output module into the logging framework. This module formats the log metadata to appropriate OTel semantic conventions (e.g., log.level), adds appropriate contextual metadata (e.g., k8s namespace), and outputs the log lines via OTLP (typically buffered) to a Collector
3) a Collector (typically, but not necessarily) on the same node as the service receives the log lines via the `otlp` receiver
4) the Collector adds additional metadata and optionally applies parsing via a Transform Processor
5) the Collector then outputs the logs downstream (either directly to Elasticsearch, or more typically through a gateway Collector, and then to Elasticsearch)

While this model is relatively simple to implement, it assumes 2 things:

1) The service can be instrumented with OpenTelemetry (either through runtime zero-configuration instrumentation, or through explicit instrumentation). This essentially rules out use of this method for most "third-party" applications and services.

2) Your OTel pipelines are robust enough to forgo file-based logging. Traditional logging relied on services writing to files and agents "tailing" those log files. File-based logging inherently adds a semi-reliable, FIFO, disk-based queue between services and the collector. If there is a downstream failure in the telemetry pipeline (e.g., a failure in the Collector or downstream of the Collector), the file will serve as a temporary, reasonably robust buffer.

That said, there are inherent advantages to using a network-based logging protocol where possible: namely:
1) not having to deal with file rotation
2) less io overhead (no file operations)
3) the Collector need not be local to the node running the applications (though you would typically want a Collector per node for other reasons)

Additionally, exporting logs from a service using the OTel SDK offers the following benefits:
1) logs are automatically formatted with OTel Semantic Conventions
2) key/values applied to log statements are automatically emitted as attributes
3) traceid and spanid are automatically added
4) contextual metadata (e.g., node name) are automatically emitted as attributes
5) baggage can be automatically applied as attributes

Configuration
===

Most of the languages supported by OpenTelemetry are automatically instrumented for logging via OTLP by default. In the case of Java, for example, the OTel SDK, when in zero-code instrumentation, will automatically attach 

Let's have a look at the logs from our `recorder-java` service:

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Copy
    ```kql
    service.name: "recorder-java"
    ```
    into the `Filter your data using KQL syntax` search bar toward the top of the Kibana window
3. Click on the refresh icon at the right of the time picker
4. Open up the first "trade committed for <customer_id>" log record

And now let's confirm these logs are coming by way of OTLP directly from service to the Collector, and not via an intermediate log file:

1. Open the [button label="VS Code"](tab-1) tab
2. Navigate to `src/recorder-java/src/main/resources/logback.xml`
3. Note that no appenders are specified in the logback configuration (they are automatically injected by the OTel SDK on startup)

Let's further validate that no logs are being written to stdout (which would be picked up and dumped to a log file by Kubernetes):

1. If it isn't already open, open a Terminal Window from the bottom of the [button label="VS Code"](tab-1) tab
2. Enter the following into the terminal to get a list of the active Kubernetes pods that comprise our trading system:
  ```bash
  kubectl -n trading get pods
  ```
2. Find the active `recorder-java-...` pod
3. Get console logs from the active pod:
  ```bash,nocopy
  kubectl -n trading logs <recorder-java-...>
  ```
  (replace ... with the pod instance id)

Note that there are no logs being written to stdout from `recorder-java` because we have not configured any appenders in the logback configuration.

This confirms that logs coming from the `recorder-java` application to our OTel Collector via OTLP, and not by way of a log file.

Attributes
===

## Attributes via Structured Logging

Let's jump back to Elasticsearch and have a closer look at the logs from our `recorder-java` service:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Copy
    ```kql
    service.name: "recorder-java"
    ```
    into the `Filter your data using KQL syntax` search bar toward the top of the Kibana window
3. Click on the refresh icon at the right of the time picker
4. Open up a "trade committed for <customer_id>" record

Now say we wanted to record a commit identifier for each record logged in our database. We could encode that into the log line itself, but then we would likely just have to parse that out later, which adds complexity. With OTel, we can easily add this as an attribute to the log record!

The SLF4J logging API supports structured logging with KeyValue pairs. The OTel SDK will automatically turn this into attributes.
1. Open the [button label="VS Code"](tab-1) tab
2. Navigate to `src/recorder-java/src/main/java/com/example/recorder/TradeRecorder.java`
3. Find the following line:
  ```
  log.atInfo().log("trade committed for " + trade.customerId);
  ```
  and change it to:
  ```
  TransactionStatus status = TransactionAspectSupport.currentTransactionStatus();
  log.atInfo().addKeyValue(Main.ATTRIBUTE_PREFIX + ".hash_code", status.hashCode()).log("trade committed for " + trade.customerId);
  ```
  Note that we can use `addKeyValue()` to add arbitrary attributes to our log lines. We prefix the attributes with `Main.ATTRIBUTE_PREFIX` as best practice to ensure no conflict with other metadata.
4. Recompile and deploy the `recorder-java` service. In the VS Code Terminal, enter:
  ```
  ./builddeploy.sh -s recorder-java
  ```

> [!NOTE]
> It is generally considered best practice to prepend any custom attributes with a prefix scoped to your enterprise, like `com.example`

Check Elasticsearch:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Close current log record
3. Click refresh
4. Open newest log record
5. Note addition of attribute `attributes.com.example.hash_code`

## Attributes via Baggage

Note that the log record has other custom attributes like `attributes.com.example.customer_id`. We didn't add that in our logging statement in `recorder-java`. How did it get there?

This is a great example of the power of using OpenTelemetry Baggage. Baggage lets us inject attributes early on in our distributed service mesh and then automatically distribute and apply them downstream to every span and log message emitted in context.

Let's see where they are coming from:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Applications` / `Service Inventory` / `Service Map`
3. Click on `trader` and select `Service Details`
4. Under `Transactions`, select `POST /trade/request`
5. Scroll down to waterfall graph
5. Click on the first span
6. Note the presence of `attributes.com.example.customer_id`
7. Close the flyout
8. Now click on the `Logs` tab to see logs associated with this trace (this works because OTel automatically stamps each log line with the current `trace.id` if generated within an active trace)
9. Find an entry from `recorder-java` of the pattern `trade committed for <customer id>`
10. Note `attributes.com.example.customer_id`

Let's look at the code which initially stuck `customer_id` into OTel baggage:

1. Open the [button label="VS Code"](tab-1) tab
2. Navigate to src/trader/app.py
3. Look for calls to `set_attribute_and_baggage` inside the `decode_common_args()` function

Here, we are pushing attributes into OTel Baggage. OTel is propagating that baggage with every call to a distributed surface. The baggage follows the context of a given span through all dependent services. Within a given service, we can leverage BaggageProcessor extensions to automatically apply metadata in baggage as attributes to the active span (including logs).

Let's add an additional attribute in our trader service.

1. In `src/trader/app.py`, add the following to the top of the decode_common_args() function:
  ```
    trade_id = str(uuid.uuid4())
    set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.trade_id", trade_id)
  ```
2. Rebuild trader service. In the VS Code Terminal, enter:
  ```
  ./builddeploy.sh -s trader
  ```
3. Open the [button label="Elasticsearch"](tab-1) tab
4. Copy
    ```kql
    service.name: "recorder-java"
    ```
    into the `Filter your data using KQL syntax` search bar toward the top of the Kibana window
5. Click on the refresh icon at the right of the time picker
6. Open up a "trade committed for <customer_id>" record
7. Note the addition of the `trade_id` attribute
8. You'll note that OTel has automatically added other things like trace_id.

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
