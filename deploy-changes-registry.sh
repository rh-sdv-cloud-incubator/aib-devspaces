#!/bin/bash
set -e

REMOTE_HOST="${REMOTE_HOST:-192.168.1.1}"
REMOTE_USER="${REMOTE_USER:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-password}"
IMAGE_BASE="${IMAGE_BASE:-radio}"
PROJECT="${PROJECT:-aib-devspaces}"  
FULL_IMAGE_NAME="${PROJECT}/${IMAGE_BASE}"
TAG="${TAG:-devspace}"
OPENSHIFT_REGISTRY="${OPENSHIFT_REGISTRY:-image-registry.openshift-image-registry.svc.cluster.local:5000}"
REGISTRY_ROUTE="${REGISTRY_ROUTE:-default-route-openshift-image-registry.apps.internal.com}"

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
TOKEN=$(oc whoami -t)

podman login -u kubeadmin -p ${TOKEN} ${OPENSHIFT_REGISTRY} --tls-verify=false 

echo "Building application locally..."
make -f Makefile.dev build-app

echo "Building container locally..."
podman build -t ${IMAGE_BASE} .

echo "Tagging image for OpenShift registry..."
podman tag ${IMAGE_BASE} ${OPENSHIFT_REGISTRY}/${FULL_IMAGE_NAME}:${TAG}

echo "Pushing image to OpenShift registry..."
podman push --tls-verify=false ${OPENSHIFT_REGISTRY}/${FULL_IMAGE_NAME}:${TAG}

if [ "$QM_MODE" = "true" ]; then
  echo "QM mode enabled: pulling image inside QM container..."
  cat << 'EOSSH' | eval ${SSH_CMD}
    set -e
    QM_PID=$(podman inspect --format '{{.State.Pid}}' qm)
    nsenter -t ${QM_PID} -n -m -u -i -p podman pull  ${REGISTRY_ROUTE}/${FULL_IMAGE_NAME}:${TAG}"
    echo "Image pulled successfully inside QM container"
EOSSH
else
  echo "Pulling image on remote host..."
  eval ${SSH_CMD} "podman login -u kubeadmin -p ${TOKEN} ${REGISTRY_ROUTE} --tls-verify=false"
  eval ${SSH_CMD} "podman pull --tls-verify=false ${REGISTRY_ROUTE}/${FULL_IMAGE_NAME}:${TAG}"
fi

echo "Deployment complete!"
