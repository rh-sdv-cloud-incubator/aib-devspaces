#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/hello.aib.template.yml"
OUTPUT_FILE="${SCRIPT_DIR}/hello.aib.yml"

NAMESPACE=$(oc project -q)
ROUTE_NAME=$(oc get routes -o name | grep artifact-server | head -1)

if [ -z "$ROUTE_NAME" ]; then
    echo "Error: No artifact server route found. Make sure the devspace is running."
    exit 1
fi

HOST=$(oc get $ROUTE_NAME -o jsonpath='{.spec.host}')

if [ -z "$HOST" ]; then
    echo "Error: Could not determine host for artifact server."
    exit 1
fi

echo "Found artifact server at: $HOST"

# Create the template file if it doesn't exist
if [ ! -f "$TEMPLATE_FILE" ]; then
    cat > "$TEMPLATE_FILE" << 'EOF'
name: hello-app

content:
  add_files:
    - path: /usr/bin/hello
      url: http://__ARTIFACT_HOST__/hello

auth:
    # "password"
    root_password: $6$xoLqEUz0cGGJRx01$H3H/bFm0myJPULNMtbSsOFd/2BnHqHkMD92Sfxd.EKM9hXTWSmELG8cf205l6dktomuTcgKGGtGDgtvHVXSWU.
EOF
    echo "Created template file: $TEMPLATE_FILE"
fi

sed "s|__ARTIFACT_HOST__|$HOST|g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "generated manifest file: $OUTPUT_FILE with artifact URL: http://$HOST/hello"
