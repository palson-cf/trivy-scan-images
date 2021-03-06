#!/usr/bin/env bash

set -e
set -o pipefail

# TODO
# clear cache because of 'latest' images

DATE=$(date +%F-%H%M)
TRIVY_DIR="/codefresh/volume/trivy"
CACHE_DIR="${TRIVY_DIR}/cache"
REPORT_DIR="${TRIVY_DIR}/reports"
REPORT_FILE="${REPORT_DIR}/report-${DATE}.json"

echoSection() {
  printf -- "--------------------------------------------\n\n"
  printf  "\n\n[INFO] $1\n\n"
}

scan_to_json() {
# TODO
# to catch  GitHub 'API rate limit exceeded' error
  local image=$1
  local format=${2:-table}
  trivy \
    -f ${format} \
    -q \
    --ignore-unfixed \
    --cache-dir ${CACHE_DIR} \
    --skip-update \
    $image
}

unset_empty_vars() {
  echoSection "Unsetting empty vars"
  for var in $(env); do 
    if [[ "${var##*=}" == "\${{${var%=*}}}" ]]; then 
      echo "Unsetting ${var%=*}"; 
      unset ${var%=*};
    fi;
  done
}



main() {
# Check images list
  if [[ -z $IMAGES_LIST ]]; then
    echo "[ERROR] The \$IMAGES_LIST variable is empty."
    exit 1
  fi

  unset_empty_vars

  echoSection "Create report dir"
  mkdir -p ${REPORT_DIR} || true

  echoSection "Create the main report file"
  echo '{"IMAGES": {}}' | jq . > ${REPORT_FILE}

  echoSection "Check connectivity to DB"
  trivy --download-db-only --cache-dir ${CACHE_DIR}

  local IFS=$',' 

  for IMAGE in $IMAGES_LIST; do
    echoSection "Scanning $IMAGE image."
    scan_to_json $IMAGE
    echo "Get the json"
    local SCAN_OBJECT=$(scan_to_json $IMAGE json)
    echo "Merge merge json with the main report file"
    jq \
      --arg image_name "${IMAGE}" \
      --argjson scanObject "${SCAN_OBJECT}" \
      '.IMAGES |= .+ {($image_name): $scanObject}' \
      $REPORT_FILE > /tmp/tmp.json && mv /tmp/tmp.json $REPORT_FILE
  done

}

main $@
