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
  path: /app/discover#/?_g=(filters:!(),query:(language:kuery,query:''),refreshInterval:(pause:!t,value:60000),time:(from:now-1h,to:now))&_a=(breakdownField:log.level,columns:!(),dataSource:(type:esql),filters:!(),hideChart:!f,interval:auto,query:(esql:'FROM%20logs-*'),sort:!(!('@timestamp',desc)))
  port: 30001
- id: kr5jkc770z5f
  title: recorder-java Source
  type: code
  hostname: host-1
  path: /workspace/workshop/src/recorder-java
- id: 4qcxxz95lkpr
  title: trader Source
  type: code
  hostname: host-1
  path: /workspace/workshop/src/trader
- id: lyqrwsofywhh
  title: Terminal
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
difficulty: ""
timelimit: 600
lab_config:
  custom_layout: '{"root":{"children":[{"branch":{"size":67,"children":[{"leaf":{"tabs":["kr5jkc770z5f","jeu1estyxf1z","4qcxxz95lkpr"],"activeTabId":"jeu1estyxf1z","size":38}},{"leaf":{"tabs":["lyqrwsofywhh"],"activeTabId":"lyqrwsofywhh","size":60}}]}},{"leaf":{"tabs":["assignment"],"activeTabId":"assignment","size":32}}],"orientation":"Horizontal"}}'
enhanced_loading: null
---
In this model, we will be sending logs directly from a service to an [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) over the network using the [OTLP](https://opentelemetry.io/docs/specs/otel/protocol/) protocol. This is the default mechanism most OpenTelemetry SDKs use for exporting logs from a service.

![method-1](../assets/method1.svg)

Looking at the diagram:
1) a service leverages an existing logging framework (e.g., [logback](https://logback.qos.ch) in Java) to generate log statements
2) on service startup, the OTel SDK injects a new Appender module into the logging framework. This module formats the log metadata to appropriate OTel semantic conventions (e.g., log.level), adds appropriate contextual metadata (e.g., trace.id), and outputs the log lines via OTLP (typically buffered) to a configured OTel Collector
3) an OTel Collector (typically, but not necessarily) on the same node as the service receives the log lines via the `otlp` receiver
4) the Collector enriches the log line with additional metadata and optionally parses or otherwise transforms the message
5) the Collector then outputs the logs downstream (either directly to Elasticsearch, or more typically through a gateway Collector, and then to Elasticsearch)

# Assumptions
While this model is relatively simple to implement, it assumes several things:
1) The service can be instrumented with OpenTelemetry (either through runtime zero-configuration instrumentation, or through explicit instrumentation). This essentially rules out use of this method for most opaque, third-party applications and services.
2) Your OTel pipelines are robust enough to forgo file-based logging. Traditional logging relied on services writing to files and agents reading or "tailing" those log files. File-based logging inherently adds a semi-reliable, FIFO, disk-based queue between services and the Collector. If there is a downstream failure in the telemetry pipeline (e.g., a failure in the Collector or downstream of the Collector) or back-pressure from Elasticsearch, the file will serve as a temporary, reasonably robust buffer. Notably, this concern can be mitigated with Collector-based disk queues and/or the use of a Kafka-like queue somewhere in-between the first Collector and Elasticsearch.

# Advantages
There are, of course, many advantages to using OTLP as a logging protocol where possible:
1) you don't have to deal with file rotation or disk overflow due to logs
2) there is less io overhead (no file operations) on the node
3) the Collector need not be local to the node running the applications (though you would typically want a Collector per node for other reasons)

Additionally, exporting logs from a service using the OTel SDK offers the following general benefits:
1) logs are automatically formatted with OTel Semantic Conventions
2) key/values applied to log statements are automatically emitted as attributes
3) traceid and spanid are automatically added when appropriate
4) contextual metadata (e.g., service.name) are automatically emitted as attributes
5) custom metadata in baggage can be automatically applied as attributes to each log line

All of the above leads to logs with rich context and metadata with little to no additional work. It is worth noting that the Collector now supports a disk-based buffer between the receivers and the exporters.

Configuration
===

Most of the languages supported by OpenTelemetry are automatically instrumented for logging via OTLP by default. In the case of Java, for example, the OTel SDK, when in zero-code instrumentation, will automatically attach an OTLP appender to either [Logback](https://github.com/open-telemetry/opentelemetry-java-instrumentation/tree/main/instrumentation/logback/logback-appender-1.0/library) or [Log4j](https://github.com/open-telemetry/opentelemetry-java-instrumentation/tree/main/instrumentation/log4j/log4j-appender-2.17/library).

In this example, we are leveraging the [OpenTelemetry Operator for Kubernetes](https://opentelemetry.io/docs/platforms/kubernetes/operator/) to automatically inject the OTel SDK into our services, including the `recorder-java` service. Our `recorder-java` service is using Logback as a logging framework with a [slf4j](https://www.slf4j.org/) facade.

Let's first validate we have logs coming in from our `recorder-java` service:

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Execute the following query:
```esql
FROM logs-* 
| WHERE service.name == "recorder-java"
```
3. Open the first log record by clicking on the double arrow icon under `Actions`
4. Click on the `Attributes` tab

You note that the `log.file.path` attribute is empty, in this case indicating this log line was delivered via OTLP without having been written to a log file.

# Checking the Source

Let's have a look at the configuration of our `recorder-java` service.

1. Open the [button label="recorder-java Source"](tab-1) tab
2. Navigate to `src/main/resources/logback.xml`
3. Note that no appenders are specified in the logback configuration (they are automatically injected by the OTel SDK on startup)

Let's further validate that no logs are being written to stdout (which would be picked up and dumped to a log file by Kubernetes):

1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following to get a list of the active Kubernetes pods that comprise our trading system:
```bash,run
kubectl -n trading get pods
```
3. Find the active `recorder-java-...` pod in the list
3. Get stdout logs from the active `recorder-java` pod:
```bash,nocopy
kubectl -n trading logs <recorder-java-...>
```
(replace ... with the pod instance id)

Note that there are no logs being written to stdout from `recorder-java` because we have not configured any appenders in the logback configuration.

This confirms that logs coming from the `recorder-java` application to our OTel Collector via OTLP, and not by way of a log file.

> [!NOTE]
> It is possible to leave a console appender in your logback configuration such that you can still view the logs locally (with `kubectl logs` or by tailing the log file itself). In this case, you would want to be sure you are explicitly excluding this log file from also being scrapped by your OTel Collector to avoid duplicative log input into Elasticsearch. We will show a straightforward way of doing this in a future challenge.

Correlation
===
One major advantage of using OTLP for logging is the ability to very easily append the active `trace.id` and `span.id` if the log is emitted during an active APM span.

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Applications` > `Service Inventory` in the left-hand navigation pane
3. Click on the `recorder-java` service
4. Click on the `Transactions` tab
5. Click on the `POST /record` tab
6. Scroll down to `Trace sample`
7. Click on the `Logs` tab

These are all the logs associated with this specific transaction. 

Attributes
===

## Attributes via Structured Logging

Let's say that we think we might have a problem with the Garbage Collector in our Java Virtual Machine (JVM) running too often, possibly affecting database performance. As a developer, you might think to sample the amount of time spent in GC and then report that in a log file.

Say we wanted to graph GC time by region to see if perhaps the issue is localized. To do that, we need GC time as a metric value. While we could just encode it into the log message as text and parse it out, that's unneccessary with modern structured logging APIs and OpenTelemetry.

OTLP logging allows us to easily add attributes to our log lines by using key/value mechanisms present in your existing logging API. In this case, we can use the `addKeyValue()` API exposed by our logging facade, slf4j.

1. Open the [button label="recorder-java Source"](tab-1) tab
2. Navigate to `src/main/java/com/example/recorder/TradeRecorder.java`
3. Find the following line:
```java,nocopy
log.atInfo().log("trade committed for " + trade.customerId);
```
and change it to:
```java
log.atInfo().addKeyValue(Main.ATTRIBUTE_PREFIX + ".gc_time", utilities.getGarbageCollectorDeltaTime()).log("trade committed for " + trade.customerId);
```

> [!NOTE]
> It is generally considered best practice to prepend any custom attributes with a prefix scoped to your enterprise, like `com.example`

Now let's recompile and redeploy our `recorder-java` service.
1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
./builddeploy.sh -s recorder-java
```

Now let's see what our logs look like in Elasticsearch.
1. Open the [button label="Elasticsearch"](tab-0) tab
2. Click `Discover` in the left-hand navigation pane
3. Execute the following query:
```esql
FROM logs-* WHERE service.name == "recorder-java" and message LIKE "trade committed"
```
4. Open the first log record by clicking on the double arrow icon under `Actions`
5. Click on the `Attributes` tab

Note the added attribute `attributes.com.example.gc_time`!

> [!NOTE]
> if `gc_time` is not yet present as an attribute, close the log line flyout, refresh the view in Discover, and try again.

Now let's graph `gc_time` to answer our question.

Execute the following query:
```esql
FROM logs-*
| WHERE service.name == "recorder-java"
| STATS count = MAX(attributes.com.example.gc_time)  BY attributes.com.example.region, BUCKET(@timestamp, 1 minute)
```

Indeed, it looks like only the "recorder-java" service deployed to the "NA" region is exhibiting this problem.

## Attributes via Baggage

Note that the log record has other custom attributes like `attributes.com.example.customer_id`. We didn't add that in our logging statement in `recorder-java`. How did it get there?

1. Click `Applications` > `Service Inventory` in the left-hand navigation pane
2. Click on the `Service Map` tab
3. Click on the `trader` service
4. Click on `Service Details`
5. Click on the `Transactions` tab
6. Scroll down and click on the `POST /trade/request` transaction under `Transactions`
7. Scroll down to the waterfall graph under `Trace sample`
8. Click on the first span `POST /trade/request` to open the flyout

Note that `attributes.com.example.customer_id` exists in this span too!

1. Close the `Transaction details` flyout
2. Click on the `Logs` tab under `Trace sample`
3. Click on the log line that looks like `traded <stock.symbol> on day <day> for <customer.id>`

Note that `attributes.com.example.customer_id` exists here too!

This is a great example of the power of using OpenTelemetry Baggage. Baggage lets us inject attributes early on in our distributed service mesh and then automatically distribute and apply them downstream to every span and log message emitted in context!

Imagine how easy this will make the life of your SREs and analysts to easily search across all of your observability signals using the inputs they are accustomed to: namely, `customer_id`, for example.

Let's look at the code which initially stuck `customer_id` into OTel baggage:

1. Open the [button label="recorder-java Source"](tab-1) tab
2. Navigate to `app.py`
3. Look for calls to `set_attribute_and_baggage()` inside the `decode_common_args()` function

Here, we are pushing attributes into OTel Baggage. OTel is propagating that baggage with every call to a distributed surface. The baggage follows the context of a given span through all dependent services. Within a given service, we can leverage BaggageProcessor extensions to automatically apply metadata in baggage as attributes to the active span (including logs).

Let's add an additional attribute in our trader service.

1. Find the following line in the `decode_common_args()` function:
```python,nocopy
    subscription = params.get('subscription', None)
```
2. Add the following to push `subscription` into baggage:
```python
    if subscription is not None:
        set_attribute_and_baggage(f"{ATTRIBUTE_PREFIX}.subscription", subscription)
```

Now let's recompile and redeploy our `trader` service.
1. Open the [button label="Terminal"](tab-3) tab
2. Execute the following:
```bash,run
./builddeploy.sh -s trader
```

And now let's check our work in Elasticsearch:

1. Click `Applications` > `Service Inventory` in the left-hand navigation pane
2. Click on the `Service Map` tab
3. Click on the `trader` service
4. Click on `Service Details`
5. Click on the `Transactions` tab
6. Scroll down and click on the `POST /trade/request` transaction under `Transactions`
7. Scroll down to the waterfall graph under `Trace sample`
8. Click on the `Logs` tab
9. Click on the `trade committed for <customer_id>` log line emitted by the `recorder-java` service
10. Note the presence of the `subscription` attribute!
