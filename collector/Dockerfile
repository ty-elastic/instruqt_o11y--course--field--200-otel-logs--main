FROM alpine:3.19 AS certs

RUN apk --update add ca-certificates

FROM golang:1.24.4 AS build-stage

RUN apt-get update
RUN apt-get install -y gettext-base

## VERSIONS
ENV OCB_VERSION=0.128.0

ENV CORE_VERSION=v$OCB_VERSION

ENV ELASTICINFRAMETRICSPROCESSOR_VERSION=v0.15.0
ENV ELASTICTRACEPROCESSOR_VERSION=v0.6.0
ENV ELASTICAPMCONNECTOR_VERSION=v0.3.0

ENV PROVIDER_VERSION=v1.33.0

ENV OCB_BINARY_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fbuilder%2Fv"$OCB_VERSION"/ocb_"$OCB_VERSION"_linux_amd64"

WORKDIR /build

COPY ./builder-config.yaml builder-config.yaml
RUN envsubst < builder-config.yaml > builder-config.yaml.tmp && mv builder-config.yaml.tmp builder-config.yaml

RUN echo $OCB_BINARY_URL
RUN wget -O ocb $OCB_BINARY_URL
RUN chmod +x ocb

RUN ./ocb --config builder-config.yaml

FROM gcr.io/distroless/base:latest

ARG USER_UID=10001
USER ${USER_UID}

COPY ./collector-config.yaml /conf/collector.yaml
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --chmod=755 --from=build-stage /build/otelcol-dev/otelcol-dev /otelcol

ENTRYPOINT ["/otelcol"]
CMD ["--config", "/conf/collector.yaml"]

EXPOSE 4317 4318 12001
