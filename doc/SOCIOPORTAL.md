# SocioPortal UI

## Test locally

```bash
docker build -t ontoportal_web_ui:test .

docker network create sp-test
docker run -d --name sp-db --network sp-test -e MYSQL_ROOT_PASSWORD=root mysql:8.0
docker run -d --name sp-cache --network sp-test memcached
sleep 30

docker run --rm --name sp-ui --network sp-test -p 3001:3000 \
  -e DB_HOST=sp-db -e BIOPORTAL_WEB_UI_DATABASE_PASSWORD=root \
  -e MEMCACHE_SERVERS=sp-cache:11211 \
  -e API_URL=http://localhost:9393 -e API_KEY=dummy \
  -e ANNOTATOR_URL=http://localhost:9393/annotator \
  -e SITE=SocioPortal -e ORG="<org>" -e ORG_URL=<org-url> \
  -e UI_URL=http://localhost:3001 -e UI_THEME=socioportal \
  -e SUPPORT_EMAIL=<email> -e RELEASE_VERSION=test \
  ontoportal_web_ui:test \
  bash -lc "bundle exec rails db:prepare && bundle exec puma -C /dev/null -b tcp://0.0.0.0:3000 -e production"
```

Open http://localhost:3001/login and hard-refresh (Ctrl+Shift+R).

## Stop and remove

Press Ctrl+C to stop `sp-ui`; it is removed automatically (`--rm`). Then:

```bash
docker rm -f sp-db sp-cache
docker network rm sp-test
```

## Push to ECR

```bash
export AWS_PROFILE=<profile>
export ACCOUNT_ID=<account-id>
export AWS_REGION=<region>
export ECR_REPO=<repo>
export TAG=<tag>
export ECR_URI=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO

aws sso login

# first time only
aws ecr create-repository --repository-name $ECR_REPO --region $AWS_REGION 

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker buildx build --platform linux/amd64 -t $ECR_URI:$TAG --push .
```