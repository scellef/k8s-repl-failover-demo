#!/usr/bin/env bash
# Perform a `vault login` to all non-DR secondary cluster instances

. ./.helper-functions.sh
. ./prepare-env.sh

PRIMARY_TOKEN=$(jq -r .root_token < ./keys/primary-init.json)

for i in north east west ; do 
  if [ $($i read -format=json sys/replication/dr/status 2> /dev/null | jq -r .data.mode 2> /dev/null) == "secondary" ] ; then
    msg info "${i^} cluster is DR secondary.  Generating new DR operation token..."
    SECONDARY_TOKEN=$(./generate-root-token.sh $i | grep '\+' | awk '{print $(NF-1)}')
    jq -r '. |= .+ {"dr_token": "'$SECONDARY_TOKEN'"}' < keys/primary-init.json > keys/$i-init.json
    for j in {0..2} ; do
      msg info "Writing token to ${i}-vault-${j}:/home/vault/.vault-token..."
      kubectl exec -it ${i}-vault-$j -- sh -c "echo $SECONDARY_TOKEN > /home/vault/.vault-token"
    done
  elif [ $($i read -format=json sys/replication/performance/status 2> /dev/null | jq -r .data.mode 2> /dev/null) == "secondary" ] ; then
    msg info "${i^} cluster is Performance secondary.  Generating new root token..."
    SECONDARY_TOKEN=$(./generate-root-token.sh $i | grep '\+' | awk '{print $(NF-1)}')
    jq -r '. | .root_token |= sub(".*"; "'$SECONDARY_TOKEN'")' < keys/primary-init.json > keys/$i-init.json
    for j in {0..2} ; do
      VAULT_TOKEN=$SECONDARY_TOKEN
      msg info "Login to pod ${i}-vault-${j}..."
      kubectl exec -it ${i}-vault-$j -- vault login -no-print $VAULT_TOKEN 
    done
  else
    for j in {0..2} ; do
      VAULT_TOKEN=$PRIMARY_TOKEN
      msg info "Login to pod ${i}-vault-${j}..."
      kubectl exec -it ${i}-vault-$j -- vault login -no-print $VAULT_TOKEN 
    done
  fi
done

msg success "Login complete!"
