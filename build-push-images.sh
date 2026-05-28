#!/usr/bin/env bash
#
# Build & push WebODM Docker images (db + webapp) to Docker Hub.
# Tags: webodm_db:db, webodm_webapp:webapp
# Requires: docker login -u anhquan01
#
# Environment variables (optional):
#   DOCKER_USER=anhquan01
#   PUSH=0|1                (default: 1)
#   BUILD_DB=0|1          (default: 1)
#   BUILD_WEBAPP=0|1      (default: 1)
#   NO_CACHE=0|1          (default: 1)
#
# Examples:
#   ./build-push-images.sh
#   PUSH=1 ./build-push-images.sh
#
set -euo pipefail

DOCKER_USER="${DOCKER_USER:-anhquan01}"
PUSH="${PUSH:-1}"
BUILD_DB="${BUILD_DB:-1}"
BUILD_WEBAPP="${BUILD_WEBAPP:-1}"
NO_CACHE="${NO_CACHE:-1}"

WEBODM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMG_DB="${DOCKER_USER}/webodm_db:db"
IMG_APP="${DOCKER_USER}/webodm_webapp:webapp"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

docker_build() {
  local context="$1"
  local dockerfile="$2"
  shift 2
  local -a cache_flag=()
  if [[ "${NO_CACHE}" == "1" ]]; then
    cache_flag=(--no-cache)
  fi
  log "docker build -f ${dockerfile} (context: ${context})"
  docker build "${cache_flag[@]}" -f "${dockerfile}" "$@" "${context}"
}

docker_push() {
  for tag in "$@"; do
    log "docker push ${tag}"
    docker push "${tag}"
  done
}

check_prerequisites() {
  command -v docker >/dev/null 2>&1 || die "docker not found"
  if [[ "${BUILD_DB}" != "1" && "${BUILD_WEBAPP}" != "1" ]]; then
    die "Set BUILD_DB=1 and/or BUILD_WEBAPP=1"
  fi
  if [[ "${PUSH}" == "1" ]]; then
    log "PUSH=1: ensure you ran 'docker login' as ${DOCKER_USER}"
  fi
}

build_db() {
  log "========== WebODM DB =========="
  docker_build "${WEBODM_DIR}/db" "${WEBODM_DIR}/db/Dockerfile" -t "${IMG_DB}"
  if [[ "${PUSH}" == "1" ]]; then
    docker_push "${IMG_DB}"
  fi
  log "Done: ${IMG_DB}"
}

build_webapp() {
  log "========== WebODM Webapp =========="
  docker_build "${WEBODM_DIR}" "${WEBODM_DIR}/Dockerfile" -t "${IMG_APP}"
  if [[ "${PUSH}" == "1" ]]; then
    docker_push "${IMG_APP}"
  fi
  log "Done: ${IMG_APP}"
}

print_summary() {
  log "========== WebODM SUMMARY =========="
  echo "Directory: ${WEBODM_DIR}"
  echo "User:      ${DOCKER_USER}"
  echo "Push:      ${PUSH}"
  echo "Build order: DB -> Webapp"
  if [[ "${BUILD_DB}" == "1" ]]; then
    echo "  DB: ${IMG_DB}"
  fi
  if [[ "${BUILD_WEBAPP}" == "1" ]]; then
    echo "  Webapp: ${IMG_APP}"
  fi
  echo ""
  echo "Update .env (already configured if using repo defaults):"
  echo "  WO_DOCKER_USER=${DOCKER_USER}"
  echo "  WO_IMAGE_TAG=webapp"
  echo "  WO_DB_IMAGE_TAG=db"
  echo "  WO_NODE_CPU_TAG=cpu"
  echo "  WO_NODE_GPU_TAG=gpu"
  echo ""
  echo "Start WebODM + NodeODX (GPU):"
  echo "  cd ${WEBODM_DIR}"
  echo "  ./webodm.sh start --gpu --detached"
  echo ""
  echo "Pull images on another server:"
  echo "  docker pull ${IMG_DB}"
  echo "  docker pull ${IMG_APP}"
  echo "  docker pull ${DOCKER_USER}/nodeodx:cpu"
  echo "  docker pull ${DOCKER_USER}/nodeodx:gpu"
}

main() {
  log "WebODM dir: ${WEBODM_DIR}"
  check_prerequisites
  if [[ "${BUILD_DB}" == "1" ]]; then
    build_db
  fi
  if [[ "${BUILD_WEBAPP}" == "1" ]]; then
    build_webapp
  fi
  print_summary
  log "WebODM build finished."
}

main "$@"
