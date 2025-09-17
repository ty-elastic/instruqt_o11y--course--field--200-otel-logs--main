arch=linux/amd64
course=latest
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
while getopts "a:c:r:v:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      r ) repo="$OPTARG" ;;
      v ) variant="$OPTARG" ;;
   esac
done

collector_distribution_image_name=$repo/otelcol

echo $collector_distribution_image_name:$course
docker buildx build \
  -t $collector_distribution_image_name:$course \
  --platform=$arch --output "type=registry,name=$collector_distribution_image_name:$course" $dir.
