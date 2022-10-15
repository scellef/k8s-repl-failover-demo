# Overview

This demo creates four Vault enterprise clusters and establishes DR and Performance replication relationships between them to provide a self-contained sandbox environment for experimenting with [HashiCorp Vault Enterprise](https://developer.hashicorp.com/vault/docs/enterprise/replication) replication [APIs](https://developer.hashicorp.com/vault/api-docs/system/replication).

# Disclaimer

This project is for demonstration/learning purposes only.  These scripts are fragile and have only been tested against a local `minikube` environment.

# Architecture

![](cluster-diagram.png)

**Unseal cluster**

* One-node dev cluster used for Transit auto-unseal

**North cluster**

* Three-node Raft cluster used for DR/Perf Primary

**West cluster**

* Three-node Raft cluster used for DR Secondary

**East cluster**

* Three-node Raft cluster used for Performance Secondary

# Usage

## Dependencies

* `jq`
* `kubectl` configured to connect to a Kubernetes cluster
* `helm` configured with [HashiCorp's official repo](https://developer.hashicorp.com/vault/docs/platform/k8s/helm/run#how-to)
* A valid Vault Enterprise license stored as a generic Secret `vault-license`, with a key-name `vault.hclic`

## Workflow

`./setup.sh`

This file initializes the deployments and configures the replication
relationships.  It will check for dependencies and a HashiCorp Vault Enterprise
license before performing the following:

1. Deploy unseal cluster
1. Configure Transform secrets engine for Transit Auto-Unseal
1. Deploy and initialize north, east, and west clusters, writing initial recovery keys and root tokens to `./keys` directory
1. Enable DR/Perf primary on north cluster
1. Enable DR secondary on west cluster
1. Enable Perf secondary on east cluster

`. ./prepare-env.sh`

This file provides a series of bash functions and aliases to interact directly
with the clusters and pods:

* `north` -- Submits `vault` CLI sub-commands to the `north-vault` service endpoint
* `north-active` -- Submits `vault` CLI sub-commands to the `north-vault-active` service endpoint (aliased to `na`)
* `north-standby` -- Submits `vault` CLI sub-commands to the `north-vault-standby` service endpoint (aliased to `ns`)
* `north-sh [0-2]` -- Starts an interactive `sh` session inside of `north-vault-0` (default) or the pod index specified in the first argument
* `north[0-2]` -- Submits `vault` CLI sub-commands to the `north-vault-n` pod via `kubectl exec`, where `n` is the pod index between `0` and `2` (aliased to `n[0-2]`)

Replace `north` with `east` or `west` to interact with those specific clusters.

`./status.sh`

Prints the cluster and replication status (in a pretty pretty table).

`./generate-dr-token.sh`

Iterates over clusters and generates a DR token on any DR secondary clusters found.

`./generate-dr-token.sh [north east west]`

Iterates over clusters and generates a root token on any non-DR secondary clusters found, or attempt to create a root token on optionally specified cluster.

`./cleanup.sh`

Attempts to sanely teardown this demo environment by uninstalling the Helm charts, removing persistent volumes the Helm chart leaves behind, and unsetting shell functions or aliases.

## TODO

* Parameterize Vault image version
* Create each cluster in its own namespace
* `failover.sh`
  * Ensure helper text explicitly describes scenario, following SOP
* `split-head.sh`
  * Ensure helper text explicitly describes scenario, following SOP and describes What Went Wrong™
* Add optional parameter to `setup.sh` to specify `primary_cluster_addr` options aimed at service endpoints
* Enable TLS by default issued from PKI engine on Unseal cluster
* Add `south` cluster to initially act as PR secondary's DR secondary
* Enable k8s auth
  * chaosmonkey mitm TLS?
* Introduce the Agent Injector into this madness
* Add chaosmonkey script to arbitrarily block pod ports
* Something something Rancher?
* Something something OpenShift?
* Allow for Consul/Other(Postgres) storage backend?
* Create/borrow synethtic load script (primarily thinking of Brian Shumate's exceptional [Blazing Sword](https://github.com/brianshumate/vaultron/blob/main/blazing_sword))
* Implement/add Vault/Helm TF providers in place of my One True Love Bash <3
* Maybe one day make robust enough to deploy Vaults across multiple k8s clusters?
  * chaosmonkey mitm k8s auth injector?
