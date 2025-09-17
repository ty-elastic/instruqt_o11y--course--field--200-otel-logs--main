rm -rf values.yaml
curl -o values.yaml https://raw.githubusercontent.com/elastic/elastic-agent/refs/tags/v9.0.3/deploy/helm/edot-collector/kube-stack/values.yaml

diff -Naru values.yaml o11y--course--field--200-otel-logs--main/values_receivercreator.yaml > o11y--course--field--200-otel-logs--main/init.patch

rm -rf values.yaml