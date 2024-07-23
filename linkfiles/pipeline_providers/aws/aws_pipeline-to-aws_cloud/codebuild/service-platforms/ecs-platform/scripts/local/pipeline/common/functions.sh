#!/bin/bash

function python_setup {
    local dir=$1

    cd "$dir" || exit 1
    pip3 install .
}

function run_mvn_clean_install {
    echo "Running mvn clean install -DskipTests"
    mvn clean install -DskipTests
}

function print_running_td {
    local profile=$1

    echo 'Printing current ECS running task definition'
    CLUSTER_ARN=$(python3 -c "import yaml;print(yaml.safe_load(open('inputs.yaml'))['ecs_cluster_arn'])")
    CLUSTER_SERVICES=$(aws ecs list-services --cluster "$CLUSTER_ARN" --output text --query 'serviceArns[]' --profile "$profile")
    for SERVICE_ARN in $CLUSTER_SERVICES
        do
            echo "Task definition for :$SERVICE_ARN"
            aws ecs describe-task-definition --task-definition $(aws ecs describe-services --cluster "$CLUSTER_ARN" --services "$SERVICE_ARN" --query "services[0].taskDefinition" --output text --profile "$profile") --profile "$profile"
    done
}

function add_ecr_image_tag {
    local image_tag=$1
    local commit_id=$2
    local repository=$3

    echo "Tagging ECR image with new tag:$image_tag-$commit_id"
    manifest=$(aws ecr batch-get-image --repository-name "$repository" --image-ids imageTag=$commit_id --output json | jq --raw-output --join-output '.images[0].imageManifest')
    aws ecr put-image --repository-name "$repository" --image-tag "$image_tag-$commit_id" --image-manifest "$manifest"
    aws ecr describe-images --repository-name "$repository"
}

function cp_docker_settings {
    # https://docs.aws.amazon.com/codebuild/latest/userguide/troubleshooting.html#troubleshooting-maven-repos
    cp ./settings.xml-DOCKERBUILD /root/.m2/settings.xml
}
