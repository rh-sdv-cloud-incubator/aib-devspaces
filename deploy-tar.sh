#!/bin/bash
set -e

REMOTE_HOST="${REMOTE_HOST:-192.168.1.1}"
REMOTE_USER="${REMOTE_USER:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-password}"
IMAGE_NAME="localhost/radio"
LOCAL_TAR_DIR="${HOME}/.container-cache"
REMOTE_TAR_DIR="/var/tmp/container-cache"
TAR_FILE="radio-image.tar"
LOCAL_TAR_PATH="${LOCAL_TAR_DIR}/${TAR_FILE}"
REMOTE_TAR_PATH="${REMOTE_TAR_DIR}/${TAR_FILE}"
FORCE_REBUILD="${FORCE_REBUILD:-no}"

if [ -z "$REMOTE_HOST" ]; then
  echo "Error: REMOTE_HOST environment variable is required"
  exit 1
fi

if [ -z "$SSH_PASSWORD" ]; then
  echo "Error: SSH_PASSWORD environment variable is required"
  exit 1
fi

SSH_CMD="sshpass -p '$SSH_PASSWORD' ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST}"
RSYNC_CMD="sshpass -p '$SSH_PASSWORD' rsync -az --progress"

mkdir -p ${LOCAL_TAR_DIR}
eval ${SSH_CMD} "mkdir -p ${REMOTE_TAR_DIR}"

echo "Building application locally..."
make -f Makefile.dev build-app

echo "Building container with updates..."
podman build -t ${IMAGE_NAME} .

echo "saving container to tar..."
rm -f ${LOCAL_TAR_PATH}
podman save ${IMAGE_NAME} -o ${LOCAL_TAR_PATH}

echo "Transferring tar to remote host using rsync..."
eval ${RSYNC_CMD} ${LOCAL_TAR_PATH} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TAR_PATH}

echo "updating container on remote host..."
cat << EOSSH | eval ${SSH_CMD}
set -e
podman load -i ${REMOTE_TAR_PATH}
EOSSH

echo "done!"
