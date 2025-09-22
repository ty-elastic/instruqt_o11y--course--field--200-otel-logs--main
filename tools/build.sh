arch=linux/amd64
course=latest
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares

while getopts "a:c:r:v:" opt
do
    case "$opt" in
        a ) arch="$OPTARG" ;;
        c ) course="$OPTARG" ;;
        r ) repo="$OPTARG" ;;
    esac
done

git clone https://github.com/elastic/ottl-playground
cp -r Dockerfile.fix ottl-playground/Dockerfile
docker buildx build --platform $arch --progress plain -t $repo/ottl-playground:$course --output "type=registry,name=$repo/ottl-playground:$course" ottl-playground
