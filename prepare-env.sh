# Pod specific functions
function north0 { kubectl exec -it north-vault-0 -- vault $@ ;} ; alias n0='north0'
function north1 { kubectl exec -it north-vault-1 -- vault $@ ;} ; alias n1='north1'
function north2 { kubectl exec -it north-vault-2 -- vault $@ ;} ; alias n2='north2'
function north-sh { kubectl exec -it north-vault-${1:-0} -- sh ;} ;

function east0 { kubectl exec -it east-vault-0 -- vault $@ ;} ; alias e0='east0'
function east1 { kubectl exec -it east-vault-1 -- vault $@ ;} ; alias e1='east1'
function east2 { kubectl exec -it east-vault-2 -- vault $@ ;} ; alias e2='east2'
function east-sh { kubectl exec -it east-vault-${1:-0} -- sh ;} ;

function west0 { kubectl exec -it west-vault-0 -- vault $@ ;} ; alias w0='west0'
function west1 { kubectl exec -it west-vault-1 -- vault $@ ;} ; alias w1='west1'
function west2 { kubectl exec -it west-vault-2 -- vault $@ ;} ; alias w2='west2'
function west-sh { kubectl exec -it west-vault-${1:-0} -- sh ;} ;

# Service Endpoint addresses
VAULT_NORTH=$(kubectl get svc north-vault -o jsonpath="{.spec.clusterIP}")
VAULT_NORTH_ACTIVE=$(kubectl get svc north-vault-active -o jsonpath="{.spec.clusterIP}")
VAULT_NORTH_STANDBY=$(kubectl get svc north-vault-standby -o jsonpath="{.spec.clusterIP}")

VAULT_EAST=$(kubectl get svc east-vault -o jsonpath="{.spec.clusterIP}")
VAULT_EAST_ACTIVE=$(kubectl get svc east-vault-active -o jsonpath="{.spec.clusterIP}")
VAULT_EAST_STANDBY=$(kubectl get svc east-vault-standby -o jsonpath="{.spec.clusterIP}")

VAULT_WEST=$(kubectl get svc west-vault -o jsonpath="{.spec.clusterIP}")
VAULT_WEST_ACTIVE=$(kubectl get svc west-vault-active -o jsonpath="{.spec.clusterIP}")
VAULT_WEST_STANDBY=$(kubectl get svc west-vault-standby -o jsonpath="{.spec.clusterIP}")

# Service Endpoint specific functions
function north { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_NORTH:8200 vault $@ ;} ;
function north-active { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_NORTH_ACTIVE:8200 vault $@ ;} ; alias na='north-active'
function north-standby { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_NORTH_STANDBY:8200 vault $@ ;} ; alias ns='north-standby'

function east { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_EAST:8200 vault $@ ;} ;
function east-active { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_EAST_ACTIVE:8200 vault $@ ;} ; alias ea='east-active'
function east-standby { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_EAST_STANDBY:8200 vault $@ ;} ; alias es='east-standby'

function west { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_WEST:8200 vault $@ ;} ;
function west-active { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_WEST_ACTIVE:8200 vault $@ ;} ; alias wa='west-active'
function west-standby { VAULT_CLIENT_TIMEOUT=5s VAULT_TOKEN=$(set_token) VAULT_ADDR=http://$VAULT_WEST_STANDBY:8200 vault $@ ;} ; alias ws='west-standby'

function set_token {
  [ -f ./keys/${FUNCNAME[1]%%-*}-init.json ] \
    && jq -r .root_token < ./keys/${FUNCNAME[1]%%-*}-init.json 2> /dev/null
}

# Ensuring shell completion for the above aliases and functions
complete -C /usr/bin/vault north ;
complete -C /usr/bin/vault north-active ; complete -C /usr/bin/vault na
complete -C /usr/bin/vault north-standby ; complete -C /usr/bin/vault ns
complete -C /usr/bin/vault north0 ; complete -C /usr/bin/vault n0
complete -C /usr/bin/vault north1 ; complete -C /usr/bin/vault n1
complete -C /usr/bin/vault north2 ; complete -C /usr/bin/vault n2

complete -C /usr/bin/vault east ;
complete -C /usr/bin/vault east-active ; complete -C /usr/bin/vault ea
complete -C /usr/bin/vault east-standby ; complete -C /usr/bin/vault es
complete -C /usr/bin/vault east0 ; complete -C /usr/bin/vault e0
complete -C /usr/bin/vault east1 ; complete -C /usr/bin/vault e1
complete -C /usr/bin/vault east2 ; complete -C /usr/bin/vault e2

complete -C /usr/bin/vault west ;
complete -C /usr/bin/vault west-active ; complete -C /usr/bin/vault wa
complete -C /usr/bin/vault west-standby ; complete -C /usr/bin/vault ws
complete -C /usr/bin/vault west0 ; complete -C /usr/bin/vault w0
complete -C /usr/bin/vault west1 ; complete -C /usr/bin/vault w1
complete -C /usr/bin/vault west2 ; complete -C /usr/bin/vault w2
