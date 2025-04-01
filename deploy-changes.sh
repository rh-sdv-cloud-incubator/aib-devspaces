#!/bin/bash
set -e

REMOTE_HOST="${REMOTE_HOST:-192.168.1.1}"
REMOTE_USER="${REMOTE_USER:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-password}"
IMAGE_NAME="localhost/radio"
QM_MODE="${QM:-false}"
QM_CONTAINER_NAME="qm"

if [ -z "$REMOTE_HOST" ]; then
  echo "Error: REMOTE_HOST environment variable is required"
  exit 1
fi

if [ -z "$SSH_PASSWORD" ]; then
  echo "Error: SSH_PASSWORD environment variable is required"
  exit 1
fi

SSH_CMD="sshpass -p ${SSH_PASSWORD} ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST}"
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

if [ "$QM_MODE" = "true" ]; then
    echo "Running in QM mode - will deploy to container within the QM container..."

    # Set up container within the QM container
    cat << EOSSH | eval ${SSH_CMD}
    set -e
    # Enter the QM container namespace
    QM_PID=\$(podman inspect --format '{{.State.Pid}}' ${QM_CONTAINER_NAME})

    # Use nsenter to run buildah commands inside the QM container
    REMOTE_CONTAINER_ID=\$(nsenter -t \$QM_PID -n -m -u -i -p buildah from ${IMAGE_NAME})
    REMOTE_MOUNT=\$(nsenter -t \$QM_PID -n -m -u -i -p buildah mount \${REMOTE_CONTAINER_ID})

    echo "\${REMOTE_MOUNT}" > /tmp/remote_mount_path
    echo "\${REMOTE_CONTAINER_ID}" > /tmp/remote_container_id
    echo "\${QM_PID}" > /tmp/qm_pid
    echo "Remote container mounted at: \${REMOTE_MOUNT} inside QM container"
EOSSH

    REMOTE_MOUNT=$(eval ${SSH_CMD} "cat /tmp/remote_mount_path")
    REMOTE_CONTAINER_ID=$(eval ${SSH_CMD} "cat /tmp/remote_container_id")
    QM_PID=$(eval ${SSH_CMD} "cat /tmp/qm_pid")

    echo "remote mount point inside QM: ${REMOTE_MOUNT}"

    echo "Transferring files to remote container filesystem inside QM..."
    buildah unshare sshpass -p ${SSH_PASSWORD} rsync -avz \
        --rsync-path="nsenter -t ${QM_PID} -n -m -u -i -p rsync" \
        -e "ssh -F /dev/null -o StrictHostKeyChecking=no" \
        "${SOURCE_MOUNT}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_MOUNT}/"

    echo "Committing changes inside QM container..."
    cat << EOSSH | eval ${SSH_CMD}
    set -e
    QM_PID=\$(cat /tmp/qm_pid)
    REMOTE_CONTAINER_ID=\$(cat /tmp/remote_container_id)

    nsenter -t \$QM_PID -n -m -u -i -p buildah umount ${REMOTE_CONTAINER_ID}
    nsenter -t \$QM_PID -n -m -u -i -p buildah commit ${REMOTE_CONTAINER_ID} ${IMAGE_NAME}
    nsenter -t \$QM_PID -n -m -u -i -p buildah rm ${REMOTE_CONTAINER_ID}
    echo "Container updated successfully inside QM container"
EOSSH

else
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

    echo "Remote mount point: ${REMOTE_MOUNT}"

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
fi

echo "Cleanup..."
buildah unshare buildah umount ${CONTAINER_ID}
buildah rm ${CONTAINER_ID}
rm -rf "${TEMP_DIR}"

echo "Done!"
