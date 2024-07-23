#!/bin/bash

function run_conftest_docker {
    echo "Configuring..."
    run_make_configure
    echo "Running conftest."
    conftest test --all-namespaces Dockerfile* --policy components/container/policy
}

function add_ecr_image_tag {
    local image_tag=$1
    local commit_id=$2
    local repository=$3

    echo "Tagging ECR image with new tag:$image_tag"
    manifest=$(aws ecr batch-get-image --repository-name "$repository" --image-ids imageTag=$commit_id --output json | jq --raw-output --join-output '.images[0].imageManifest')
    aws ecr put-image --repository-name "$repository" --image-tag "$image_tag" --image-manifest "$manifest"
}