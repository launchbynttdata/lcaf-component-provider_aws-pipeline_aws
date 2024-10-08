#!/bin/bash
DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
LOCAL_FUNCTIONS="${DIR}/../../../local/pipeline/common/functions.sh"

if [ -f $LOCAL_FUNCTIONS ]; then
    # shellcheck source=/dev/null
    source "${LOCAL_FUNCTIONS}"
else
    exit 1
fi

function simulated_merge {
    set_vars_script_and_clone_service
    git_checkout "origin/${TO_BRANCH}" "${CODEBUILD_SRC_DIR}/${GIT_REPO}"
    sim_merge "origin/${FROM_BRANCH}" "${CODEBUILD_SRC_DIR}/${GIT_REPO}"
    if [ "${IGNORE_INTERNALS}" != "true" ]; then
        check_git_changes_for_internals "${MERGE_COMMIT_ID}" "${BUILD_BRANCH}" || echo "git change result: $?"
    fi
}

function pre_deploy_test {
    echo "legacy deprecated, migrating to launch-cli: #136"
}

function tf_post_deploy_functional_test {
    echo "legacy deprecated, migrating to launch-cli: #137"
}

function certify_env {
    install_asdf "${HOME}"
    set_vars_script_and_clone_service
    add_git_tag "${CERTIFY_PREFIX}-${MERGE_COMMIT_ID}" "${MERGE_COMMIT_ID}" "${CODEBUILD_SRC_DIR}/${GIT_REPO}"
}

function trigger_pipeline {
    set_vars_script_and_clone_service
    create_global_vars_script \
        "${MERGE_COMMIT_ID}" \
        "${LATEST_COMMIT_HASH}" \
        "${GIT_PROJECT}" \
        "${GIT_REPO}" \
        "${FROM_BRANCH}" \
        "${TO_BRANCH}" \
        "${PROPERTIES_REPO_SUFFIX}" \
        "${GIT_SERVER_URL}" \
        "${IMAGE_TAG_PREFIX}" \
        "${SERVICE_COMMIT}" \
        "${CODEBUILD_SRC_DIR}" \
        "${GIT_ORG}"
    git_checkout \
        "${MERGE_COMMIT_ID}" \
        "${CODEBUILD_SRC_DIR}/${GIT_REPO}"
    if [ "${IGNORE_INTERNALS}" != "true" ] && check_git_changes_for_internals "${MERGE_COMMIT_ID}" "${BUILD_BRANCH}"; then
        export USERVAR_S3_CODEPIPELINE_BUCKET=${INTERNALS_CODEPIPELINE_BUCKET}
    fi
    copy_zip_to_s3_bucket "${USERVAR_S3_CODEPIPELINE_BUCKET}" "${CODEBUILD_SRC_DIR}"
}

function codebuild_status {
    set_vars_from_script "${CODEBUILD_SRC_DIR}/set_vars.sh"
    if [[ "$GIT_SERVER_URL" == *"github.com"* ]]; then
        echo "GIT_SERVER_URL found to be github, callback is not available for github."
        return 0
    fi
    codebuild_status_callback \
        "${MERGE_COMMIT_ID}" 
        "${GIT_SERVER_URL}" 
        "${GIT_USERNAME}" 
        "${GIT_TOKEN}" 
        "${IS_PIPELINE_LAST_STAGE}" 
        "${CODEBUILD_BUILD_SUCCEEDING}" 
        "${CODEBUILD_BUILD_URL}" 
        "${CODEBUILD_BUILD_ID}"
}

function set_global_vars {
    if [ -z "$SOURCE_REPO_URL" ]; then
        echo "SOURCE_REPO_URL not found: ${SOURCE_REPO_URL}"
    else
        protocol="${SOURCE_REPO_URL%%://*}://"
        domain="${SOURCE_REPO_URL#*://}"
        base="${domain%%/*}"
        export GIT_SERVER_URL="$protocol$base"
        export GIT_REPO=$(echo "$SOURCE_REPO_URL" | sed 's|.*/||' | sed "s/\.git$//")
        echo "GIT_SERVER_URL: ${GIT_SERVER_URL}"
        echo "GIT_REPO: ${GIT_REPO}"
    fi

    if [ -z "$GIT_ORG" ]; then
        if [ -z "$SOURCE_REPO_URL" ]; then
            echo "[ERROR] cannot find repository url for git org"
            export GIT_ORG="scm/${GIT_PROJECT}"
        else
            domain="${SOURCE_REPO_URL#*://}"
            base="${domain%%/*}"
            export GIT_ORG=$(echo "${domain}" | sed "s/^${base}\///" | sed "s/\/${GIT_REPO}\.git$//")
            echo "GIT_ORG: ${GIT_ORG}"
        fi
    fi

    export PROPERTIES_REPO_SUFFIX=$(get_properties_suffix "${GIT_PROPERTIES_SUFFIX}")
}

function set_commit_vars {
    if [ -z "$LATEST_COMMIT_HASH" ]; then
        if [ "$GIT_REPO" == "${GIT_REPO%"$PROPERTIES_REPO_SUFFIX"}" ]; then
            export LATEST_COMMIT_HASH="${SERVICE_COMMIT}"
        else
            export LATEST_COMMIT_HASH="${PROPS_COMMIT}"
        fi
    fi

    if [ -z "$MERGE_COMMIT_ID" ]; then
        git_checkout "${FROM_BRANCH}" "${CODEBUILD_SRC_DIR}/${GIT_REPO}"
        MERGE_COMMIT_ID=$(git -C "${CODEBUILD_SRC_DIR}/${GIT_REPO}" rev-parse "${FROM_BRANCH}")
        git checkout -
    fi
}

function git_clone_service {
    local trimmed_git_url="${GIT_SERVER_URL#https://}/${GIT_ORG}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}.git"
    git_clone \
        "$SVC_BRANCH" \
        "https://$GIT_USERNAME:$GIT_TOKEN@${trimmed_git_url}" \
        "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}" &&
        SERVICE_COMMIT=$(git -C "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}" rev-parse HEAD)
    export SERVICE_COMMIT
    echo "${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"} HEAD commit: ${SERVICE_COMMIT}"
}

function git_clone_service_using_app_token {
    GIT_TOKEN=$(launch github auth application --application-id-parameter-name "$GITHUB_APPLICATION_ID" --installation-id-parameter-name "$GITHUB_INSTALLATION_ID" --signing-cert-secret-name "$GITHUB_SIGNING_CERT_SECRET_NAME")
    export GIT_TOKEN

    local trimmed_git_url="${GIT_SERVER_URL#https://}/${GIT_ORG}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}.git"
    git_clone \
        "$SVC_BRANCH" \
        "https://x-access-token:$GIT_TOKEN@${trimmed_git_url}" \
        "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}" &&
        SERVICE_COMMIT=$(git -C "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}" rev-parse HEAD)
    export SERVICE_COMMIT
    echo "${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"} HEAD commit: ${SERVICE_COMMIT}"
}

function git_clone_service_properties {
    local trimmed_git_url="${GIT_SERVER_URL#https://}/${GIT_ORG}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}${PROPERTIES_REPO_SUFFIX}.git"
    git_clone \
        "$SVC_PROP_BRANCH" \
        "https://$GIT_USERNAME:$GIT_TOKEN@${trimmed_git_url}" \
        "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}${PROPERTIES_REPO_SUFFIX}" &&
        PROPS_COMMIT=$(git -C "${CODEBUILD_SRC_DIR}/${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}${PROPERTIES_REPO_SUFFIX}" rev-parse HEAD)
    export PROPS_COMMIT
    echo "${GIT_REPO%"${PROPERTIES_REPO_SUFFIX}"}${PROPERTIES_REPO_SUFFIX} HEAD commit: ${PROPS_COMMIT}"
}

function set_vars_script_and_clone_service {
    set_vars_from_script "${CODEBUILD_SRC_DIR}/set_vars.sh" "${BUILD_BRANCH}" "${TO_BRANCH}"
    set_global_vars
    git_config "${GIT_USERNAME}@${GIT_EMAIL_DOMAIN}" "${GIT_USERNAME}"
    git_clone_service_using_app_token
    set_commit_vars
}