FROM nginx:alpine

# Install gettext for envsubst
RUN apk add --no-cache gettext

# Copy the HTML template and entrypoint script
COPY index.html /usr/share/nginx/html/index.html.template
COPY entrypoint.sh /docker-entrypoint.d/99-envsubst.sh

# Make the entrypoint script executable
RUN chmod +x /docker-entrypoint.d/99-envsubst.sh

# Nginx alpine image automatically runs scripts in /docker-entrypoint.d/ before starting nginx
EXPOSE 80
