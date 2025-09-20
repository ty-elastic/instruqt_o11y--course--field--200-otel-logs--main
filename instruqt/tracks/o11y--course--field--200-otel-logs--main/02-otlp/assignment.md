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

In this model, we will be sending logs directly from a service to an [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) over the network using the [OTLP](https://opentelemetry.io/docs/specs/otel/protocol/) protocol. This is the default mechanism most OpenTelemetry SDKs use for exporting logs from a service.

![method-1](../assets/method1.svg)

Looking at the diagram:
1) A service leverages an existing logging framework (e.g., [logback](https://logback.qos.ch) in Java) to generate log statements
2) On startup, the OTel SDK automatically injects a new Appender module into the logging framework. This module formats the log metadata to appropriate OTel semantic conventions (e.g., log.level), adds appropriate contextual metadata (e.g., trace.id), and outputs the log lines via OTLP (typically buffered) to a configured OTel Collector
3) an OTel Collector (typically, but not necessarily) on the same node as the service receives the log lines via the `otlp` receiver
4) the Collector adds additional metadata and optionally parses or otherwise transforms the messages
5) the Collector then outputs the logs downstream (either directly to Elasticsearch, or more typically through a gateway Collector, and then to Elasticsearch)

# Assumptions
While this model is relatively simple to implement, it assumes 2 things:
1) The service can be instrumented with OpenTelemetry (either through runtime zero-configuration instrumentation, or through explicit instrumentation). This essentially rules out use of this method for most opaque, third-party applications and services.

2) Your OTel pipelines are robust enough to forgo file-based logging. Traditional logging relied on services writing to files and agents reading or "tailing" those log files. File-based logging inherently adds a semi-reliable, FIFO, disk-based queue between services and the Collector. If there is a downstream failure in the telemetry pipeline (e.g., a failure in the Collector or downstream of the Collector) or back-pressure from Elasticsearch, the file will serve as a temporary, reasonably robust buffer. Notably, this concern can be mitigated with Collector-based disk queues and/or the use of a Kafka-like queue somewhere in-between the first Collector and Elasticsearch. Such a service is, in fact, provided by Elastic's Managed OpenTelemetry Collector.

# Advantages
There are, of course, many advantages to using OTLP as a logging protocol where possible:
1) you don't have to deal with log file rotation or disk overflow
2) there is less io overhead (no file operations) on the node
3) the Collector need not be local to the node running the applications (though you would typically want a Collector per node for other reasons)

Additionally, exporting logs from a service using the OTel SDK offers the following general benefits:
1) logs are automatically formatted with OTel Semantic Conventions
2) key/values applied to log statements are automatically emitted as attributes
3) traceid and spanid are automatically added when appropriate
4) contextual metadata (e.g., node name) are automatically emitted as attributes
5) custom metadata in baggage can be automatically applied as attributes to each log line

All of the above leads to logs with rich context and metadata, increasing this utility and value.

Configuration
===

Most of the languages supported by OpenTelemetry are automatically instrumented for logging via OTLP by default. In the case of Java, for example, the OTel SDK, when in zero-code instrumentation, will automatically attach an OTLP appender to either [Logback](https://github.com/open-telemetry/opentelemetry-java-instrumentation/tree/main/instrumentation/logback/logback-appender-1.0/library) or [Log4j](https://github.com/open-telemetry/opentelemetry-java-instrumentation/tree/main/instrumentation/log4j/log4j-appender-2.17/library).

We are using the OTel Operator to automatically instrument our `recorder-java` service. 

Let's have a look at the logs from our `recorder-java` service:

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Execute the following query:
    ```esql
    FROM logs-* WHERE service.name == "recorder-java"
    ```
    into the ES|QL input window toward the top of the Kibana window
3. Open up the first "trade committed for <customer_id>" log record

# OTLP, not log files

Let's convince ourselves that no logs are being written to disk.

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

Correlation
===

Let's see some of those advantages we talked about in action! For one, any log statement emitted in the context of a span will automatically be tagged with the current trace.id and span.id. What makes this incredibly powerful is that we can then see all of our logs in one place for a given trace.

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Applications` > `Service Inventory` in the left-hand navigation pane
3. Click on the `recorder-java` service
4. Click on the `transactions` tab
5. Click on the `POST /record` tab
6. Scroll down to `Trace sample`
7. Click on the `Logs` tab

These are all the logs associated with this specific transaction. How does this work? That OTel appender is automatically adding `trace.id` and `span.id`.

1. Open 

1. Elastic APM
2. Trader
3. Transactions
4. Scroll to bottom
5. Trace Sample
6. Logs

Find a log line from recorder-java and pop it open. Note the presence of a trace.id attribute. This was automatically added for us by the OTel SDK.

Attributes
===

## Attributes via Structured Logging

Let's say that we think we might have a problem with the Garbage Collector in our Java Virtual Machine (JVM) running too often, possibly affecting database performance. As a developer, you might think to sample the amount of time spent in GC and then report that in a log file.

Say we wanted to graph GC time by region to see if perhaps the issue is localized. To do that, we need GC time as a metric value. While we could just encode it into the log message as text and parse it out, that's unneccessary with OTel structured logging.

OTel logging supports adding attributes to log lines using your logging system's key/value pair mechanism. Let's see how this work:

1. Open the [button label="VS Code"](tab-1) tab
2. Navigate to `src/recorder-java/src/main/java/com/example/recorder/TradeRecorder.java`
3. Find the following line:
  ```
  log.atInfo().log("trade committed for " + trade.customerId);
  ```
  and change it to:
  ```
  log.atInfo().addKeyValue(Main.ATTRIBUTE_PREFIX + ".gc_time", utilities.getGarbageCollectorDeltaTime()).log("trade committed for " + trade.customerId);

  ```
4. Recompile and deploy the `recorder-java` service. In the VS Code Terminal, enter:
  ```
  ./builddeploy.sh -s recorder-java
  ```

> [!NOTE]
> It is generally considered best practice to prepend any custom attributes with a prefix scoped to your enterprise, like `com.example`

Check Elasticsearch
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
    ```esql
    FROM logs-* WHERE service.name == "recorder-java"
    ```
    into the ES|QL input window toward the top of the Kibana window
4. Open up the first "trade committed for <customer_id>" log record

Note the added attribute `attributes.com.example.gc_time`.

Let's graph it to answer our question.

Execute the following query:
```esql
FROM logs-*
| WHERE service.name == "recorder-java"
| STATS count = MAX(attributes.com.example.gc_time)  BY attributes.com.example.region, BUCKET(@timestamp, 1 minute)
```

Indeed, it looks like only the "recorder-java" service deployed to the "NA" region is exhibiting this problem.

## Attributes via Baggage

Note that the log record has other custom attributes like `attributes.com.example.customer_id`. We didn't add that in our logging statement in `recorder-java`. How did it get there?

This is a great example of the power of using OpenTelemetry Baggage. Baggage lets us inject attributes early on in our distributed service mesh and then automatically distribute and apply them downstream to every span and log message emitted in context.

Let's see where they are coming from:
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Applications` > `Service Inventory` in the left-hand navigation pane
3. Click on the `recorder-java` service
4. Click on the `transactions` tab
5. Click on the `POST /record` tab
6. Scroll down to the waterfall graph under `Trace sample`
5. Click on the database span `INSERT trades.trades`
6. Note the presence of `attributes.com.example.customer_id`
7. Close the flyout
8. Now click on the `Logs` tab to see logs associated with this trace (this works because OTel automatically stamps each log line with the current `trace.id` if generated within an active trace)
9. Find an entry from `recorder-java` of the pattern `trade committed for <customer id>`
10. Note `attributes.com.example.customer_id`

This is incredibly powerful: we have common attributes applied to every span and log message. Imagine how easy this will make the life of your SREs and analysts to easily search across all of your observability signals using the inputs they are accustomed to: namely, customer_id, for example.

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

look at service map. start at trader, follow to recorder-java.

super powerful stuff.
