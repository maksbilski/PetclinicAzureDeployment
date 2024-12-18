##!/bin/bash

FRONTEND_HOST="${PETCLINIC_ANGULAR_FRONTEND_PUBLIC_IP}"
FRONTEND_USER="azureuser"
DOCKER_BUILD_DIR="/tmp/petclinic-angular-build"
REMOTE_TARGET_DIR="/usr/share/nginx/html/petclinic"

mkdir -p $DOCKER_BUILD_DIR

cat << 'DOCKERFILE' > $DOCKER_BUILD_DIR/Dockerfile
FROM node:18

WORKDIR /app
RUN git clone https://github.com/spring-petclinic/spring-petclinic-angular.git .

# Stwórz plik environment.prod.ts
RUN mkdir -p src/environments && \
    echo 'export const environment = { \n\
    production: true, \n\
    REST_API_URL: "/petclinic/api/" \n\
};' > src/environments/environment.prod.ts

RUN npm install -g @angular/cli
RUN npm install
RUN ng build --configuration=production

RUN chown -R 1000:1000 /app/dist
DOCKERFILE

echo "Building Docker image..."
docker build -t petclinic-angular-builder $DOCKER_BUILD_DIR

echo "Copying build files from container..."
docker run --name petclinic-angular-build petclinic-angular-builder /bin/true
docker cp petclinic-angular-build:/app/dist $DOCKER_BUILD_DIR/
docker rm petclinic-angular-build

echo "Uploading files to frontend server..."
ssh $FRONTEND_USER@$FRONTEND_HOST "sudo mkdir -p $REMOTE_TARGET_DIR && sudo chown $FRONTEND_USER:$FRONTEND_USER $REMOTE_TARGET_DIR"
scp -r $DOCKER_BUILD_DIR/dist/* $FRONTEND_USER@$FRONTEND_HOST:$REMOTE_TARGET_DIR/
ssh $FRONTEND_USER@$FRONTEND_HOST "sudo chown -R www-data:www-data $REMOTE_TARGET_DIR"

echo "Cleaning up..."
rm -rf $DOCKER_BUILD_DIR

echo "Build and deploy completed! Files are in place."
