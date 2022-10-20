#!/usr/bin/env bash
# Stand-up four Vault clusters via Helm to establish a sandbox for testing
# Enterprise replication

source ./.helper-functions.sh
trap cleanup_int SIGINT

msg aloha "Starting demo!  This will create three 3-node Raft clusters and a 1-node"
msg aloha "Transit Auto-unseal cluster to establish Performance and DR replication"
msg aloha "relationships between them in the following way:"
msg aloha "
                          DR/Perf Primary
                              ∇ North
                            ↗ ↓ ↖
                           ↑  ∇ ⟵↑  Unseal
                           ↑ ↗ ↖ ↑
                      West ∇     ∇ East
                      DR 2nd     Perf 2nd"

# Move into temporary project directory
PROJECT_DIR='./keys'
msg info "Creating directory '$PROJECT_DIR'"
mkdir -p $PROJECT_DIR && pushd $PROJECT_DIR > /dev/null

check_license() {
# Check if a k8s secret `vault-license` exists with key-name `vault.hclic`
  msg info "Confirming Vault license exists..."
  LICENSE_NAME=$(kubectl get secrets vault-license -o jsonpath={.metadata.name} 2> /dev/null)
  if [ -z "$LICENSE_NAME" -o "$LICENSE_NAME" != "vault-license" ] ; then
    msg warn "Vault license not found in secrets.  Please paste your license (or Ctrl-C to exit): "
    read LICENSE
    kubectl create secret generic vault-license --from-literal=vault.hclic=$LICENSE
  fi
}

set_vault_version() {
# Parse env vars for image version
  if [ -n "$VAULT_IMAGE" ] ; then
    msg info "\$VAULT_IMAGE set: \"$VAULT_IMAGE\""
  else
    VAULT_IMAGE="hashicorp/vault-enterprise"
  fi

  if [ -n "$VAULT_VERSION_TAG" ] ; then
    msg info "\$VAULT_VERSION_TAG set: \"$VAULT_VERSION_TAG\""
  else
    VAULT_VERSION_TAG="latest"
  fi

  msg info "Using image \"${VAULT_IMAGE}:${VAULT_VERSION_TAG}\""
}

setup_unseal_cluster() {
# Standup dev server to be used as Transit auto-unseal target
  msg info "Deploying Unseal cluster"
  helm install unseal hashicorp/vault \
    --set=server.dev.enabled=true \
    --set=server.dev.devRootToken=root \
    --set=server.standalone.enabled=true \
    --set=server.image.repository=$VAULT_IMAGE \
    --set=server.image.tag=$VAULT_VERSION_TAG \
    --set=server.enterpriseLicense.secretName=vault-license \
    --set=server.enterpriseLicense.secretKey=vault.hclic \
    --set=server.extraArgs="-dev-ha -dev-transactional" \
    --set=injector.enabled=false \
    --set=global.tlsDisable=true > /dev/null

  msg info "Waiting until Unseal cluster pod is ready..."
  until [ $(sleep 1 ; kubectl get pod unseal-vault-0 -o json | jq .status.containerStatuses[].ready) == "true" ] 2> /dev/null ; do
    sleep 2
  done

  msg info "Preparing Transit auto-unseal"
  kubectl exec -it unseal-vault-0 -- vault login -no-print root
  kubectl exec -it unseal-vault-0 -- vault secrets enable transit
  kubectl exec -it unseal-vault-0 -- vault write -f transit/keys/autounseal
  kubectl exec -it unseal-vault-0 -- sh -c 'vault policy write autounseal - << EOF
path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
 }

 path "transit/decrypt/autounseal" {
    capabilities = [ "update" ]
  }
EOF'

# Set the precious Transit token, abuse global variables
  TRANSIT_TOKEN=$(kubectl exec -it unseal-vault-0 -- vault token create -format=json -policy="autounseal" | jq -r .auth.client_token)
}

setup_cluster() {
# Setup 3-node Raft cluster with Transit auto-unseal via Helm chart
  msg info "Deploying ${1^} cluster "
  helm install $1 hashicorp/vault \
    --set=server.affinity='' \
    --set=server.ha.enabled=true \
    --set=server.ha.raft.enabled=true \
    --set=server.ha.raft.replicas=3 \
    --set=server.image.repository=$VAULT_IMAGE \
    --set=server.image.tag=$VAULT_VERSION_TAG \
    --set=server.enterpriseLicense.secretName=vault-license \
    --set=server.enterpriseLicense.secretKey=vault.hclic \
    --set=server.logLevel=trace \
    --set=injector.enabled=false \
    --set=global.tlsDisable=true \
    --set-string='server.ha.raft.config=
  ui = true

  service_registration "kubernetes" {}
  raw_storage_endpoint = true

  listener "tcp" {
    address = ":8200"
    cluster_address = ":8201"
    tls_disable = 1
    telemetry {
      unauthenticated_metrics_access = true
    }
  }

  telemetry {
    prometheus_retention_time = "24h"
    disable_hostname = true
  }

  seal "transit" {
    address = "http://unseal-vault-0.unseal-vault-internal:8200"
    key_name = "autounseal"
    mount_path = "transit"
    token = "'$TRANSIT_TOKEN'"
  }

  storage "raft" {
    path = "/vault/data"
    retry_join {
      leader_api_addr = "http://'${1}'-vault-0.'${1}'-vault-internal:8200"
    }
    retry_join {
      leader_api_addr = "http://'${1}'-vault-1.'${1}'-vault-internal:8200"
    }
    retry_join {
      leader_api_addr = "http://'${1}'-vault-2.'${1}'-vault-internal:8200"
    }
  }
  ' > /dev/null
}

initialize_cluster() {
# Initialize cluster with single recovery key, write JSON init output to
# $PROJECT_DIR/<CLUSTER_NAME>-init.json
  msg info "Waiting for ${1^} cluster to be ready..."
  sleep 3
  until [ $(sleep 2 ; kubectl get pod ${1}-vault-0 -o json | jq .status.containerStatuses[].started) == "true" ] 2> /dev/null ; do
    sleep 1
  done
  until [ $(sleep 2 ; kubectl get pod ${1}-vault-1 -o json | jq .status.containerStatuses[].started) == "true" ] 2> /dev/null ; do
    sleep 1
  done
  until [ $(sleep 2 ; kubectl get pod ${1}-vault-2 -o json | jq .status.containerStatuses[].started) == "true" ] 2> /dev/null ; do
    sleep 1
  done

  msg info "Initializing ${1^} cluster"
  kubectl exec -it ${1}-vault-0 -- vault operator init --format=json -recovery-shares=1 -recovery-threshold=1 > ${1}-init.json
  msg info "Recovery key and root token written to '$PROJECT_DIR/${1}-init.json'"
}

enable_replication() {
# Configure replication type ($1) and role ($2) on the named cluster ($3)
  if [ "$1" == "dr" ] ; then
    msg info "Enabling ${1^^} ${2^} replication on ${3^} cluster"
  else
    msg info "Enabling ${1^} ${2^} replication on ${3^} cluster"
  fi

  # Create ~/.vault-token on presumed active node
  ROOT_TOKEN=$(jq -r .root_token < ./${3}-init.json)
  kubectl exec -it ${3}-vault-0 -- vault login -no-print $ROOT_TOKEN
  case "$2" in
    primary)
      kubectl exec -it ${3}-vault-0 -- vault write -f sys/replication/${1}/${2}/enable
      cp -f ${3}-init.json primary-init.json
      PRIMARY=$3
      ;;
    secondary)
      SECONDARY_TOKEN=$(kubectl exec -it ${PRIMARY}-vault-0 -- \
        vault write -f -format=json sys/replication/${1}/primary/secondary-token id=$3 | \
        jq -r .wrap_info.token)
      kubectl exec -it ${3}-vault-0 -- vault write -f sys/replication/${1}/${2}/enable token=$SECONDARY_TOKEN
      mv ${3}-init.json ${3}-init.json.no-longer-valid
      sleep 2

      # This is to workaround intermittent issue where standby nodes seal
      # themselves after secondary replication is enabled
      msg info "Rolling ${3^} cluster pods to unseal on new barrier"
      kubectl scale statefulset ${3}-vault --replicas=0
      kubectl scale statefulset ${3}-vault --replicas=3
      ;;
  esac
}

final_confirmation() {
# Wait until all clusters and their members are up before declaring success
  msg info "Confirming cluster readiness..."
  until [ "$(kubectl get statefulsets.apps -o json | jq '.items[] | select(.metadata.name=="north-vault") | .status.readyReplicas')" == "3" ] 2> /dev/null ; do
    sleep 1
  done
  until [ "$(kubectl get statefulsets.apps -o json | jq '.items[] | select(.metadata.name=="west-vault") | .status.readyReplicas')" == "3" ] 2> /dev/null ; do
    sleep 1
  done
  until [ "$(kubectl get statefulsets.apps -o json | jq '.items[] | select(.metadata.name=="east-vault") | .status.readyReplicas')" == "3" ] 2> /dev/null ; do
    sleep 1
  done
}


## Main workflow
check_deps
check_license
set_vault_version

setup_unseal_cluster
setup_cluster north
setup_cluster east
setup_cluster west

initialize_cluster north
initialize_cluster east
initialize_cluster west

enable_replication performance primary north
enable_replication performance secondary east
enable_replication dr primary north
enable_replication dr secondary west

final_confirmation
msg success "Setup complete!"
msg aloha "If you deployed to minikube, source the 'prepare-env.sh' file to "
msg aloha "interact with the clusters: "
msg aloha
msg aloha "    . ./prepare-env.sh"
msg aloha
msg aloha "Make sure your k8s service endpoints are accessible. If you're using"
msg aloha "minikube, run the following in a separate terminal: "
msg aloha
msg aloha "    minikube tunnel"
msg aloha
msg aloha "Alternatively, create a port-forward to your desired pod via kubetl: "
msg aloha
msg aloha "    kubectl port-forward north-vault-0 18200:8200 "
msg aloha "    export VAULT_ADDR=http://localhost:18200"
msg aloha
msg aloha "Happy replicating!"
