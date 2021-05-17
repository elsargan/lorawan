#!/bin/bash

# Remove any old files/folders
echo "Removing Old data files and folders"
sudo rm -rf acme blob .env *.pem
ls -a

# Certificates (generate self signed certs)
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout key.pem -out cert.pem
sudo chmod 777 *.pem

docker-compose pull

docker-compose run --rm stack is-db init

docker-compose run --rm stack is-db create-admin-user \
--id admin \
--email jerry3k@hotmail.com

docker-compose run --rm stack is-db create-oauth-client \
--id cli \
--name "Command Line Interface" \
--owner admin \
--no-secret \
--redirect-uri "local-callback" \
--redirect-uri "code"

docker-compose run --rm stack is-db create-oauth-client \
--id console \
--name "Console" \
--owner admin \
--secret ee60607d8e8ca7ffe947b9b36ede52a3d4e54a9b28a581b8ef41e3728c2023bc  \
--redirect-uri "/console/oauth/callback"

docker-compose up -d

# --callback false
