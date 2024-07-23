#!/bin/bash
DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
LOCAL_FUNCTIONS="${DIR}/../../../local/pipeline/common/functions.sh"

if [ -f $LOCAL_FUNCTIONS ]; then
  # shellcheck source=/dev/null
  source "${LOCAL_FUNCTIONS}"
else
  exit 1
fi

function conftest_container {
    install_asdf "${HOME}"
    set_vars_script_and_clone_service
    git_checkout "${MERGE_COMMIT_ID}" "${CODEBUILD_SRC_DIR}/${GIT_REPO}"
    tool_versions_install "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}"
    assume_iam_role "${ROLE_TO_ASSUME}" "${TARGETENV}" "${AWS_REGION}"
    set_netrc "${GIT_SERVER_URL}" "${GIT_USERNAME}" "${GIT_TOKEN}"
    cd_deploy_dir "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}"
    run_conftest_docker
}

function tag_container {    
    install_asdf "${HOME}"
    set_vars_script_and_clone_service
    git_checkout "${MERGE_COMMIT_ID}" "${CODEBUILD_SRC_DIR}/${GIT_REPO}"
    tool_versions_install "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}"
    set_netrc "${GIT_SERVER_URL}" "${GIT_USERNAME}" "${GIT_TOKEN}"
    run_make_configure
    local version_tag=$(run_launch_github_version_predict "${FROM_BRANCH}")
    add_ecr_image_tag "${version_tag}" "${MERGE_COMMIT_ID}" "${GIT_REPO}"
}