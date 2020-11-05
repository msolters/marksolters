#!/usr/bin/env bash

cat <<EOF >skaffold.yaml
apiVersion: skaffold/v1beta13
kind: Config
build:
  googleCloudBuild:
    projectId: ${PROJECT_ID}
  artifacts:
  - image: marksolters-v1
  tagPolicy:
    envTemplate:
      template: "{{.DOCKER_REPO}}/{{.IMAGE_NAME}}:{{.GIT_HASH}}"
deploy:
  kustomize:
    path: .
EOF
