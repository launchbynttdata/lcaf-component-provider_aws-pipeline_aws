#!/bin/bash
LOCAL_FUNCTIONS="../../../local/pipeline/common/functions.sh"

if [ -f $LOCAL_FUNCTIONS ]; then
  # shellcheck source=/dev/null
  source "${LOCAL_FUNCTIONS}"
else
  exit 1
fi

function certify_image {
    set_vars_from_script "${CODEBUILD_SRC_DIR}/set_vars.sh"
    add_ecr_image_tag "${NEW_IMAGE_TAG}" "${MERGE_COMMIT_ID}" "${CONTAINER_IMAGE_NAME}"
}

function set_make_vars_and_artifact_token {
    echo "Setting make vars"
    export JOB_NAME="${GIT_USERNAME}"
    export JOB_EMAIL="${GIT_USERNAME}@${GIT_EMAIL_DOMAIN}"
    CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token --domain "${CODEARTIFACT_DOMAIN}" --domain-owner "${CODEARTIFACT_OWNER}" --query authorizationToken --output text)
    export CODEARTIFACT_AUTH_TOKEN
}

# TODO:
function integration_test {
    echo "Integration test commands would go here"
}

function auto_qa {
    echo "Auto QA commands would go here"
}