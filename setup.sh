#! /bin/bash

# Back to base path
cd ~

gcloud services enable iam.googleapis.com
gcloud services enable deploymentmanager.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com

gcloud config set compute/region us-east1
gcloud config set compute/zone us-east1-b

export PROJECT=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects list --filter=$PROJECT --format="value(PROJECT_NUMBER)")

export ZONE=$(gcloud config get-value compute/zone)
export REGION=$(gcloud config get-value compute/region)

export CLUSTER_NAME="apigee-istio-lab"
# Remove cluster version ENV var as the dropdown items change....
# export CLUSTER_VERSION="1.14.6-gke.13"

# Create GKE Cluster
gcloud container clusters create $CLUSTER_NAME --num-nodes 3 --zone $ZONE --project $PROJECT

# Create Cluster Admin role in K8s for core/account user
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)

# Connect to GKE Cluster
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT

# Get Istio 1.2.2
curl -L https://git.io/getLatestIstio | ISTIO_VERSION=1.2.2 sh -

# Switch to Istio directory
cd ./istio-1.2.2

# Add Istio to PATH
export PATH=$PWD/bin:$PATH

# Install Istio Control Plane
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done

# Validate CRDs for Istio are Deployed
kubectl get crds

# Continue with Istio Install
kubectl apply -f install/kubernetes/istio-demo.yaml

# Back to base path
cd ~

# Get Mixer Adapter
mkdir apigee-istio-adapter
cd apigee-istio-adapter
wget https://github.com/apigee/istio-mixer-adapter/releases/download/1.2.0/istio-mixer-adapter_1.2.0_linux_64-bit.tar.gz
tar xvf istio-mixer-adapter_1.2.0_linux_64-bit.tar.gz

export PATH=$PATH:$PWD;cd -

# Enable Sidecar Injection
kubectl label namespace default istio-injection=enabled

# Wait for injector pod to be up and running...
while [[ $(kubectl get pods -l app=sidecarInjectorWebhook -n istio-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 10; done

# Deploy application - Use default virtual service rules to begin
cd ~
mkdir HelloWorldApigeeIstioLab
cd HelloWorldApigeeIstioLab/
gsutil cp -r gs://apigee-quest/data/manifests .
mkdir proxy-releases
cd proxy-releases
wget https://storage.googleapis.com/apigee-quest/apiproxies/lab16.apiproxy.zip

cd ~/HelloWorldApigeeIstioLab
kubectl apply -f manifests/helloworld/helloworld.yaml
kubectl apply -f manifests/helloworld/helloworld-gateway.yaml
kubectl apply -f manifests/helloworld/virtual-service-default.yaml
kubectl apply -f manifests/helloworld/destination-rule-all.yaml
kubectl apply -f manifests/helloworld/jwt-lua-filter.yaml

# Wait for injector pod to be up and running...
while [[ $(kubectl get pods -l app=helloworld -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True True" ]]; do echo "waiting for pod" && sleep 5; done

cd ~
