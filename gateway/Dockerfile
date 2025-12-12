FROM nginx:alpine

# Copy nginx configuration from gateway directory
COPY gateway/nginx.conf /etc/nginx/nginx.conf

# Expose port 8080 (Fly.io standard)
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
