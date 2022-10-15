#!/usr/bin/env bash
# Creates a root token on all or specified cluster and prints it

. ./.helper-functions.sh
. ./prepare-env.sh

trap cleanup SIGINT

cleanup() {
# Cancel any unfinished attempts if Ctrl-C is hit
 if [ $($VAULT operator generate-root -status -format=json | jq .started) == 'true' ] ; then
   $VAULT operator generate-root -cancel
 fi
}

generate_root_token() {
# Grab list of keys, init token generation, and return output
  LIST_OF_KEYS="$(jq -r .recovery_keys_b64[] < ./keys/primary-init.json)"
  OTP=$($VAULT operator generate-root -format=json -init | jq -r .otp) 
  NONCE=$($VAULT operator generate-root -format=json -status | jq -r .nonce) 

  for KEY in $LIST_OF_KEYS ; do
    ENCODED_TOKEN=$($VAULT operator generate-root -nonce=$NONCE -format=json - <<< $KEY | jq -r .encoded_token) 
  done 

  $VAULT operator generate-root -nonce=$NONCE -decode=$ENCODED_TOKEN -otp=$OTP
}

print_root_token() {
# Print a friendly message with the resultant token
  VAULT=$1
  msg info "Generating token for ${1^} cluster:"
  ROOT_TOKEN=$(generate_root_token)
  msg success "${1^} Root Token: $ROOT_TOKEN"
}

determine_valid_cluster() {
# Determine if cluster is a DR secondary or not
  MODE=$($1 read -format=json sys/replication/dr/status 2> /dev/null | jq -r .data.mode 2> /dev/null)
  if [ "$MODE" == "secondary" ] ; then
    msg info "${1^} cluster is a DR secondary, skipping..."
  else
    print_root_token $1
  fi
}

parse_arguments() {
# Parse options and either generate on specified cluster, or all valid clusters
  if [ -z "$1" ] ; then
    msg aloha "Determining Primary and Performance clusters..."
    for i in north east west ; do
      determine_valid_cluster $i
    done
  else
    case $1 in
      north)
        determine_valid_cluster $1 ;;
      east)
        determine_valid_cluster $1 ;;
      west)
        determine_valid_cluster $1 ;;
      *) 
        msg error "Invalid cluster: $1.  Specify a cluster from [north east west]" ;;
    esac
  fi
}

parse_arguments $1

# Cleanup any unfinished attempts if we make it this far
[ -n "$VAULT" -a "$MODE" == "secondary" ] && $VAULT operator generate-root -cancel 1>&2 > /dev/null
