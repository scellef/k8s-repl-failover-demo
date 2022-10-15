#!/usr/bin/env bash
# Collect relevant status output on the state of the clusters

. ./.helper-functions.sh
. ./prepare-env.sh

# Variables for drawing printf table
SEPARATOR="--------------------"                 # 20 '-' characters
SEPARATOR="${SEPARATOR}${SEPARATOR}${SEPARATOR}" # 3*20 '-' characters
TABLE_WIDTH="60"                                 # 60 character table width
ROWS="%-10s| %-10s| %-12s| %-12s| %d\n"

check_cluster_status() {
# Print cluster statuses from `kubectl`
  msg info "Current statefulsets:
kubectl get statefulsets.apps -l app.kubernetes.io/name=vault"
  kubectl get statefulsets.apps -l app.kubernetes.io/name=vault

  msg info "Current active nodes:
kubectl get pods -l app.kubernetes.io/name=vault -l vault-active=true"
  kubectl get pods -l app.kubernetes.io/name=vault -l vault-active=true
}

check_repl_status() {
# Parse replication status from each of the clusters, print in a pretty pretty table
  if [ "$1" == "dr" ] ; then
    msg info "${1^^} Replication Status: "
    WAL=".last_dr_wal"
  else 
    msg info "${1^} Replication Status: "
    WAL=".last_performance_wal"
  fi
  printf "%-10s| %-10s| %-12s| %-12s| %-11s\n" Cluster Mode State Status Last_WAL
  printf "%.${TABLE_WIDTH}s\n" $SEPARATOR
  for i in north east west ; do 
    MODE=$($i read -format=json sys/replication/${1}/status 2> /dev/null | jq -r .data.mode 2> /dev/null)
    if [ "$MODE" == "primary" ] ; then
      printf "$ROWS" "${i^}" $($i read -format=json sys/replication/${1}/status 2> /dev/null | 
        jq ".data | [.mode, .state, .secondaries[].connection_status, $WAL] | .[]" -r) 2> /dev/null
    elif [ "$MODE" == "secondary" ] ; then
      printf "$ROWS" "${i^}" $($i read -format=json sys/replication/${1}/status 2> /dev/null | 
        jq '.data | [.mode, .state, .primaries[].connection_status, .last_remote_wal] | .[]' -r) 2> /dev/null
    else 
      printf "$ROWS" "${i^}" "disabled"
    fi
  done
}

check_cluster_status
check_repl_status dr
check_repl_status performance
