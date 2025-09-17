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

for dir in java/*/; do
    echo $dir
    if [[ -d "$dir" ]]; then
        extension=$(basename "$dir")
        docker buildx build --platform $arch --progress plain -t $repo/$extension:$course --output "type=registry,name=$repo/$extension:$course" $dir
    fi
done
