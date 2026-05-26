#!/bin/sh
set -e

# Get the container IP
export CONTAINER_IP=$(hostname -i | awk '{print $1}')

# Set default values if environment variables are not provided
export EC2_INSTANCE_ID=${EC2_INSTANCE_ID:-"Unknown/Local"}
export EC2_AZ=${EC2_AZ:-"Unknown/Local"}

# Substitute environment variables in the HTML file
# We use a temporary file to avoid issues during substitution
envsubst '${EC2_INSTANCE_ID} ${EC2_AZ} ${CONTAINER_IP}' < /usr/share/nginx/html/index.html.template > /usr/share/nginx/html/index.html

# Execute the CMD (nginx)
exec "$@"
