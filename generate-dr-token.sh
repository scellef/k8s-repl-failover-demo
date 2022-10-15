#!/usr/bin/env bash
# Find the DR secondary and generate a DR operation token using the primary's recovery key(s)

. ./.helper-functions.sh
. ./prepare-env.sh

trap cleanup SIGINT

cleanup() {
# Cancel any unfinished attempts if Ctrl-C is hit
 if [ $($VAULT operator generate-root $DR_FLAG -status -format=json | jq .started) == 'true' ] ; then
   $VAULT operator generate-root $DR_FLAG -cancel
 fi
}

generate_dr_token() {
# Grab list of keys, init token generation, and return output
  LIST_OF_KEYS="$(jq -r .recovery_keys_b64[] < ./keys/primary-init.json)"
  OTP=$($VAULT operator generate-root -dr-token -format=json -init | jq -r .otp) 
  NONCE=$($VAULT operator generate-root -dr-token -format=json -status | jq -r .nonce) 

  for KEY in $LIST_OF_KEYS ; do
    ENCODED_TOKEN=$($VAULT operator generate-root -dr-token -nonce=$NONCE -format=json - <<< $KEY | jq -r .encoded_token) 
  done 

  $VAULT operator generate-root -dr-token -nonce=$NONCE -decode=$ENCODED_TOKEN -otp=$OTP
}

determine_dr_secondary() {
# Iterate through clusters until a DR Secondary is found
  msg aloha "Determining DR secondary clusters..."
  for i in north east west ; do
    MODE=$($i read -format=json sys/replication/dr/status 2> /dev/null | jq -r .data.mode 2> /dev/null)
    if [ "$MODE" == "secondary" ] ; then
      VAULT=$i
      msg info "Generating token for ${i^} cluster:"
      DR_TOKEN=$(generate_dr_token)
      msg success "${i^} DR Token: $DR_TOKEN"
    fi
  done
}

determine_dr_secondary

# Cleanup any unfinished attempts if we make it this far
$VAULT operator generate-root -dr-token -cancel > /dev/null
