#!/bin/bash
set -e

SERVICE=$1
ENVIRONMENT=$2
PROJECT_PATH=$3
SERVICE_PATH=$4
DOCKERFILE_PATH=$5

GIT_COMMIT_SHA=$(git rev-parse HEAD)
DEPLOY_SCRIPT_TIMESTAMP=$(date +"%s")
TAG=$GIT_COMMIT_SHA.$DEPLOY_SCRIPT_TIMESTAMP
ENVIRONMENT_NAME=lunch-lottery-$ENVIRONMENT
SERVICE_ROOT=$PROJECT_PATH/$SERVICE_PATH
DOCKERFILE=$SERVICE_ROOT/$DOCKERFILE_PATH
SERVICE_NAME=lunch-lottery-$SERVICE
SERVICE_TAG=$SERVICE_NAME:$TAG
SECRET_NAME=lunch-lottery-$SERVICE-secrets
CONFIGMAP_NAME=lunch-lottery-$SERVICE-configmap
DEPLOY_PATH=$PROJECT_PATH/deploy

# define login functions
gigster_network_login() {
    GCP_PROJECT_ID=${GCP_PROJECT_ID:-gde-lunch-lottery}
    GCP_ACCOUNT_ID=${GCP_ACCOUNT_ID:-$(gcloud config get-value account)}
    echo "Deploying with google account $GCP_ACCOUNT_ID"
    if ! echo "$GCP_ACCOUNT_ID" | grep -q "@gigsternetwork.com$"; then
      echo "WARNING: $GCP_ACCOUNT_ID is not allowed to deploy. Sign in using a gigsternetwork google account: \`gcloud auth login <account>@gigsternetwork.com\`";
    fi
    SERVICE_IMAGE=gcr.io/$GCP_PROJECT_ID/$SERVICE_TAG
    KUBE_CONTEXT=${KUBE_CONTEXT:-gke_gde-core_us-east1-c_gde-core}

    echo "yes" | gcloud auth configure-docker --project $GCP_PROJECT_ID
}

if [ "$ENVIRONMENT" = "prod" ]; then
  gigster_network_login
  PROVIDER_KIND=gcp
  echo "Pushing images to the gigster-network provider on $PROVIDER_KIND"
fi
if [ "$ENVIRONMENT" = "staging" ]; then
  gigster_network_login
  PROVIDER_KIND=gcp
  echo "Pushing images to the gigster-network provider on $PROVIDER_KIND"
fi

# build the docker image
docker build -f "$DOCKERFILE" -t $SERVICE_TAG $SERVICE_ROOT
docker tag $SERVICE_TAG $SERVICE_IMAGE
docker push $SERVICE_IMAGE

# create the configmap
kubectl delete configmap $CONFIGMAP_NAME -n=$ENVIRONMENT_NAME --context $KUBE_CONTEXT || echo \
  "Failed to delete deployment configmap. OK for first time deployment."
echo "$DEPLOY_PATH"
touch "$DEPLOY_PATH"/$ENVIRONMENT/.config
kubectl create configmap $CONFIGMAP_NAME --from-env-file="$DEPLOY_PATH"/$ENVIRONMENT/.config -n=$ENVIRONMENT_NAME --context $KUBE_CONTEXT

# create the secrets
kubectl delete secret $SECRET_NAME -n=$ENVIRONMENT_NAME --context $KUBE_CONTEXT || echo \
  "Failed to delete deployment secrets. OK for first time deployment."
touch "$DEPLOY_PATH"/$ENVIRONMENT/.env
kubectl create secret generic $SECRET_NAME --from-env-file="$DEPLOY_PATH"/$ENVIRONMENT/.env -n=$ENVIRONMENT_NAME --context $KUBE_CONTEXT

# apply the manifests to the environment
# start
cp "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/start-job.yaml "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/start-job-tmp.yaml
sed -i.bak "s|__IMAGE__|$SERVICE_IMAGE|" "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/start-job-tmp.yaml
kubectl apply -f "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/start-job-tmp.yaml -n=$ENVIRONMENT_NAME --context $KUBE_CONTEXT
rm "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/start-job-tmp.yaml.bak
rm "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/start-job-tmp.yaml

# remind
cp "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/remind-job.yaml "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/remind-job-tmp.yaml
sed -i.bak "s|__IMAGE__|$SERVICE_IMAGE|" "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/remind-job-tmp.yaml
kubectl apply -f "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/remind-job-tmp.yaml -n=$ENVIRONMENT_NAME --context $KUBE_CONTEXT
rm "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/remind-job-tmp.yaml.bak
rm "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/remind-job-tmp.yaml

# end
cp "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/end-job.yaml "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/end-job-tmp.yaml
sed -i.bak "s|__IMAGE__|$SERVICE_IMAGE|" "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/end-job-tmp.yaml
kubectl apply -f "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/end-job-tmp.yaml -n=$ENVIRONMENT_NAME --context $KUBE_CONTEXT
rm "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/end-job-tmp.yaml.bak
rm "$DEPLOY_PATH"/cronjob_manifests-"$ENVIRONMENT"/end-job-tmp.yaml

echo "All Done!"
