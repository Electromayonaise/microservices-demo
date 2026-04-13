#!/bin/bash
# deploy-local.sh
# Deploys the full microservices-demo stack to a local kind cluster.
# Usage: ./scripts/deploy-local.sh [github-username] [branch]
#
# Examples:
#   ./scripts/deploy-local.sh electromayonaise main
#   ./scripts/deploy-local.sh electromayonaise develop

set -e

GITHUB_USER=${1:-"electromayonaise"}
BRANCH=${2:-"develop"}
REPO="ghcr.io/${GITHUB_USER}/microservices-demo"

VOTE_IMAGE="${REPO}/vote:${BRANCH}"
WORKER_IMAGE="${REPO}/worker:${BRANCH}"
RESULT_IMAGE="${REPO}/result:${BRANCH}"

echo "========================================="
echo " Deploying microservices-demo to kind"
echo " User:   ${GITHUB_USER}"
echo " Branch: ${BRANCH}"
echo "========================================="

# Verify kind cluster is running
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: No Kubernetes cluster found."
  echo "Create one with: kind create cluster --name microservices-demo"
  exit 1
fi

echo ""
echo "[1/5] Deploying infrastructure (Kafka + PostgreSQL)..."
helm upgrade --install infrastructure infrastructure/ \
  --wait --timeout 5m

echo ""
echo "[2/5] Deploying vote service..."
helm upgrade --install vote vote/chart/ \
  --set image=${VOTE_IMAGE} \
  --wait --timeout 5m

echo ""
echo "[3/5] Deploying result service..."
helm upgrade --install result result/chart/ \
  --set image=${RESULT_IMAGE} \
  --wait --timeout 5m

echo ""
echo "[4/5] Deploying worker service..."
helm upgrade --install worker worker/chart/ \
  --set image=${WORKER_IMAGE} \
  --wait --timeout 5m

echo ""
echo "[5/5] Verifying deployment..."
kubectl get pods

echo ""
echo "========================================="
echo " Deploy complete!"
echo "========================================="
echo ""
echo "To access the vote app:"
echo "  kubectl port-forward svc/vote 9090:8080"
echo "  Open http://localhost:9090"
echo ""
echo "To access the result app:"
echo "  kubectl port-forward svc/result 9091:80"
echo "  Open http://localhost:9091"
