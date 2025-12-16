course=latest
service=all
local=false
variant=none
otel=false
namespace=trading
region=0

while getopts "l:c:s:v:o:n:r:" opt
do
   case "$opt" in
      c ) course="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      l ) local="$OPTARG" ;;
      v ) variant="$OPTARG" ;;
      o ) otel="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      r ) region="$OPTARG" ;;
   esac
done

repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
if [ "$local" = "true" ]; then
    repo=localhost:5093
fi

export COURSE=$course
export REPO=$repo
export NAMESPACE=$namespace
export REGION=$region

if [ "$otel" = "true" ]; then
    # ---------- COLLECTOR

    cd collector
    helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
    --namespace opentelemetry-operator-system \
    --values 'values.yaml' \
    --version '0.10.5'
    cd ..

    sleep 30
fi

envsubst < k8s/yaml/_namespace.yaml | kubectl apply -f -

if [ "$service" != "none" ]; then
    for file in k8s/yaml/*.yaml; do
        current_service=$(basename "$file")
        current_service="${current_service%.*}"
        echo $current_service
        echo $service
        echo $REGION
        if [[ "$service" == "all" || "$service" == "$current_service" ]]; then
            echo "deploying..."
            envsubst < k8s/yaml/$current_service.yaml | kubectl apply -f -
            kubectl -n $namespace rollout restart deployment/$current_service
        fi
    done
fi
