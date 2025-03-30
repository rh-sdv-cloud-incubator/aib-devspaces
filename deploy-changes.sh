#!/bin/bash
set -e

REMOTE_HOST="${REMOTE_HOST:-192.168.1.1}"
REMOTE_USER="${REMOTE_USER:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-password}"
IMAGE_NAME="localhost/radio"

if [ -z "$REMOTE_HOST" ]; then
  echo "Error: REMOTE_HOST environment variable is required"
  exit 1
fi

if [ -z "$SSH_PASSWORD" ]; then
  echo "Error: SSH_PASSWORD environment variable is required"
  exit 1
fi

SSH_CMD="sshpass -p ${SSH_PASSWORD} ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST}"
SCP_CMD="sshpass -p ${SSH_PASSWORD} scp -o StrictHostKeyChecking=no"
RSYNC_CMD="sshpass -p ${SSH_PASSWORD} rsync -avz -e \"ssh -o StrictHostKeyChecking=no\""

echo "Building application locally..."
make -f Makefile.dev build-app

echo "Building container locally..."
podman build -t ${IMAGE_NAME} .

echo "Setting up container for rsync on source..."
CONTAINER_ID=$(buildah from ${IMAGE_NAME})
SOURCE_MOUNT=$(buildah unshare buildah mount ${CONTAINER_ID})
echo "Container mounted at: ${SOURCE_MOUNT}"

TEMP_DIR=$(mktemp -d)
echo "${SOURCE_MOUNT}" > "${TEMP_DIR}/source_mount_path"

echo "transferring mount path info to remote host..."
${SCP_CMD} "${TEMP_DIR}/source_mount_path" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/source_mount_path"

echo "Setting up container on remote host..."
cat << EOSSH | eval ${SSH_CMD}
set -e
REMOTE_CONTAINER_ID=\$(buildah from ${IMAGE_NAME})
REMOTE_MOUNT=\$(buildah mount \${REMOTE_CONTAINER_ID})
echo "\${REMOTE_MOUNT}" > /tmp/remote_mount_path
echo "\${REMOTE_CONTAINER_ID}" > /tmp/remote_container_id
echo "Remote container mounted at: \${REMOTE_MOUNT}"
EOSSH

REMOTE_MOUNT=$(eval ${SSH_CMD} "cat /tmp/remote_mount_path")
REMOTE_CONTAINER_ID=$(eval ${SSH_CMD} "cat /tmp/remote_container_id")

echo "remote mount point: ${REMOTE_MOUNT}"

echo "Transferring files to remote container filesystem..."
buildah unshare sshpass -p ${SSH_PASSWORD} rsync -avz -e "ssh -F /dev/null -o StrictHostKeyChecking=no" "${SOURCE_MOUNT}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_MOUNT}/"

echo "Committing changes on remote host..."
cat << EOSSH | eval ${SSH_CMD}
set -e
buildah umount ${REMOTE_CONTAINER_ID}
buildah commit ${REMOTE_CONTAINER_ID} ${IMAGE_NAME}
buildah rm ${REMOTE_CONTAINER_ID}
echo "Container updated successfully on remote host"
EOSSH

echo "cleanup..."
buildah unshare buildah umount ${CONTAINER_ID}
buildah rm ${CONTAINER_ID}
rm -rf "${TEMP_DIR}"

echo "done!"
