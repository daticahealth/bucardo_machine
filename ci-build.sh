#!/bin/bash -e
#
# Usage:
#    $ ./ci-build.sh
#
# To run this script locally and not have it push the image to docker hub each
# time, run the script as follows.
#
#    $ DEBUG=true ./ci-build.sh
#
cd build

IMAGE_TAG=${CI_COMMIT_REF_NAME//\//\-}.${CI_COMMIT_SHA:0:8}

if [ -z ${CI_COMMIT_REF_NAME} ]; then
  CI_COMMIT_REF_NAME=$(git rev-parse --abbrev-ref HEAD)
  CI_COMMIT_SHA=$(git rev-list HEAD --max-count=1 --abbrev-commit)
  IMAGE_TAG=${CI_COMMIT_REF_NAME//\//\-}.${CI_COMMIT_SHA}
fi

echo "!! Building"
docker build --compress --no-cache --force-rm -t datica/bucardo_machine:${IMAGE_TAG} -f Dockerfile .

docker images

if [[ ${CI_COMMIT_REF_NAME} =~ ^rc-.*$ ]]; then
  EXTRA_TAG="latest_rc"
else
  EXTRA_TAG=""
fi

if [ -n "$EXTRA_TAG" ]; then
  docker tag datica/bucardo_machine:${IMAGE_TAG} datica/bucardo_machine:$EXTRA_TAG
fi

if [ -z $DEBUG ]; then
  echo "!! Pushing"
  echo "Running: docker push datica/bucardo_machine:${IMAGE_TAG}"
  docker push datica/bucardo_machine:${IMAGE_TAG}

  if [ -n "$EXTRA_TAG" ]; then
    echo "Running: docker push datica/bucardo_machine:$EXTRA_TAG"
    docker push datica/bucardo_machine:$EXTRA_TAG
  fi
  if [[ ${CI_COMMIT_REF_NAME} == master ]]; then
    echo "Running: docker tag datica/bucardo_machine:${IMAGE_TAG} datica/bucardo_machine:latest"
    docker tag datica/bucardo_machine:${IMAGE_TAG} datica/bucardo_machine:latest
    echo "Running: docker push datica/bucardo_machine:latest"
    docker push datica/bucardo_machine:latest
  fi
fi

echo "!! Cleaning up"
docker ps |grep "datica/bucardo_machine" |awk '{print $1}' |xargs -r docker kill
docker container prune -f --filter "until=24h"
docker image prune -a -f --filter "until=24h"
