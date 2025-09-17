FROM gradle:8 AS build  

WORKDIR /work

COPY gradle gradle
COPY build.gradle .
COPY gradle.properties .
COPY gradlew .
COPY gradlew.bat .
COPY settings.gradle .

RUN wget https://github.com/open-telemetry/opentelemetry-java-contrib/archive/refs/heads/main.zip
RUN unzip main.zip
RUN mv opentelemetry-java-contrib-main/baggage-processor/src src
RUN rm -rf main.zip
RUN rm -rf src/test

RUN mv src/main/java/io/opentelemetry/contrib src/main/java/io/opentelemetry/test
RUN sed -i "s,io.opentelemetry.contrib.baggage.processor,io.opentelemetry.test.baggage.processor,g" src/main/java/io/opentelemetry/test/baggage/processor/*.java
RUN sed -i "s,io.opentelemetry.contrib.baggage.processor,io.opentelemetry.test.baggage.processor,g" src/main/resources/META-INF/services/*

RUN sed -i "s,java.experimental,java.test,g" src/main/java/io/opentelemetry/test/baggage/processor/BaggageProcessorCustomizer.java

RUN --mount=type=cache,target=/root/.gradle ./gradlew build -x test

FROM alpine:latest

COPY --from=build /work/build/libs/io-opentelemetry-test-baggage-processor-1.0-all.jar /extensions/io-opentelemetry-test-baggage-processor.jar
