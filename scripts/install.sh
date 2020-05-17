#!/bin/bash

KIND_VERSION="v0.8.1"
METALLB_VERSION="v0.9.3"


# Functions
function log {
	echo "$(date) [gimme-k8s]: $1" 
}

# Intro screen
log "
############################################
#  Gimme k8s!                              # 
#    http://github.com/jrcichra/gimme-k8s  #
#      by: Justin Cichra                   #
#        0->k8s->0 with no reminents       #
############################################
"

# Explain what we're doing
log "Checking for dependencies..."


# Make sure we have script dependencies
if [ ! -x $(which jq) ];then
	log "jq is not installed - please install it with 'sudo apt install jq' if you're on Ubuntu/Debian"
	return 1
fi

# Make sure docker is installed
if [ ! -x $(which docker) ];then
	log "docker is not installed - please install it with 'sudo apt install docker.io if you're on Ubuntu/Debian"
	return 1
fi

log "Downloading KinD/kubectl binaries to current directory..."

# Get a local copy of kind if we don't have it from the clone
if [ ! -f "./kind" ];then
        log "kind not found in the current directory...downloading..."
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-$(uname)-amd64"
	chmod +x ./kind
fi

# Get a local copy of kubectl if we don't have it from the clone
if [ ! -f "./kubectl" ];then
	log "kubectl not found in the current directory...downloading..."
	curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
	chmod +x ./kubectl
fi


# Create a cluster
log "Creating a single node Kubernetes cluster inside a docker container..."
./kind create cluster --name gimme-k8s --config yaml/kind.yaml
# Apply Metallb (from their installation guide)
log "Installing the LoadBalancer (MetalLB)..."
./kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/manifests/namespace.yaml
./kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/manifests/metallb.yaml
./kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
# Apply a configmap that gives some address space on (bridge)
KIND_CIDR=$(docker network inspect kind | jq -j -r '.[0].IPAM.Config[0].Subnet')
KIND_NET_PREFIX=$(echo "${KIND_CIDR}" | sed 's@/.*@@g' | sed 's@\.0\.0@@g')
METALLB_ADDRESSES="${KIND_NET_PREFIX}.255.1-${KIND_NET_PREFIX}.255.250"
METALLB_CONFIGMAP="
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses: 
      - ${METALLB_ADDRESSES}
"
echo "$METALLB_CONFIGMAP" | ./kubectl apply -f -
# Load a customized version of the Kubernetes dashboard with wide-open permissions and LoadBalancer
log "Installing the dashboard..."
./kubectl apply -f yaml/dashboard.yaml

# Get the loadbalanced IP address of their KinD cluster
WAIT_AMOUNT=10
log "Waiting for the dashboard to start and get an IP address..."
while [ "$(./kubectl get svc -n kubernetes-dashboard --selector=k8s-app=kubernetes-dashboard -o json | jq -j -r '.items[0].status.loadBalancer.ingress[0].ip')" == "null" ]
do
	sleep ${WAIT_AMOUNT}
	log "Kubernetes dashboard has not started yet...waiting $WAIT_AMOUNT seconds and checking again..."
	# Show a listing of the pods starting
	./kubectl get pods -n kubernetes-dashboard
done

# Give the user a summary
DASHBOARD_IP=$(./kubectl get svc -n kubernetes-dashboard --selector=k8s-app=kubernetes-dashboard -o json | jq -j -r '.items[0].status.loadBalancer.ingress[0].ip')
log "You've successfully deployed a Kubernetes cluster! You can view your dashboard at: http://${DASHBOARD_IP}."
