#!/bin/bash
set -euo pipefail

# vars 
REMOTE_HOST="${REMOTE_HOST:-192.168.1.1}"
REMOTE_USER="${REMOTE_USER:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-password}"

IMAGE_BASE="${IMAGE_BASE:-radio}"         
PROJECT="${PROJECT:-aib-devspaces}"
TAG="${TAG:-devspace}"                   

OPENSHIFT_REGISTRY="${OPENSHIFT_REGISTRY:-image-registry.openshift-image-registry.svc.cluster.local:5000}"
REGISTRY_ROUTE="${REGISTRY_ROUTE:-default-route-openshift-image-registry.apps.com}"

BUILD_BC="${IMAGE_BASE}-build"             

# local build of binaries only 
make -f Makefile.dev build-app          

# ensure ImageStream + BuildConfig exist 
oc -n "$PROJECT" get imagestream "$IMAGE_BASE" >/dev/null 2>&1 || \
  oc -n "$PROJECT" create imagestream "$IMAGE_BASE"

if ! oc -n "$PROJECT" get bc "$BUILD_BC" >/dev/null 2>&1; then
cat <<EOF | oc apply -n "$PROJECT" -f -
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: ${BUILD_BC}
spec:
  output:
    to:
      kind: ImageStreamTag
      name: "${IMAGE_BASE}:${TAG}"
  source:
    type: Binary
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
EOF
fi

# start OpenShift binary build
echo "Starting OpenShift build …"
tar -cf - Dockerfile radio-client radio-service engine-service entrypoint.sh | \
  oc -n "$PROJECT" start-build "$BUILD_BC" --from-archive=- --wait --follow
echo "Image pushed to ${OPENSHIFT_REGISTRY}/${PROJECT}/${IMAGE_BASE}:${TAG}"

# remote pull + login
TOKEN=$(oc whoami -t)
SSH_CMD="sshpass -p ${SSH_PASSWORD} ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST}"

echo "Pulling image on remote host…"
eval "$SSH_CMD" "podman login -u kubeadmin -p ${TOKEN} ${REGISTRY_ROUTE} --tls-verify=false"
eval "$SSH_CMD" "podman pull --tls-verify=false ${REGISTRY_ROUTE}/${PROJECT}/${IMAGE_BASE}:${TAG}"

echo "Deployment complete!"
