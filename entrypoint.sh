#!/usr/bin/env bash

set -e
set -o pipefail

# TODO
# clear cache because of 'latest' images

DATE=$(date +%F-%H%M)
TRIVY_DIR="/codefresh/volume/trivy/"
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
  trivy -f json -q --ignore-unfixed --cache-dir ${CACHE_DIR} $image | jq .[]
}

main() {
# Check images list
  if [[ -z $IMAGES_LIST ]]; then
    echo "[ERROR] The \$IMAGES_LIST variable is empty."
    exit 1
  fi

  echoSection "Create report dir"
  mkdir -p ${REPORT_DIR} || true

  echoSection "Create the main report file"
  echo '{"images": []}' | jq . > ${REPORT_FILE}


  local IFS=$',' 
  for image in $IMAGES_LIST; do

    echoSection "Scanning $image image."
    local scan_object=$(scan_to_json $image)

    echoSection "Merge $image report with main file"
    jq --argjson scanObject "$scan_object" '.images[.images|length] |= .+ $scanObject' $REPORT_FILE > /tmp/tmp.json && mv /tmp/tmp.json $REPORT_FILE
  done

}

main $@
