#!/usr/bin/env bash
# Uninstall Helm charts, remove associated PVCs

source ./.helper-functions.sh
msg aloha "Cleaning up!"
msg info "Uninstalling Helm charts"
helm uninstall $(helm list -o json | jq -r '.[].name | select(.=="unseal"//.=="north"//.=="east"//.=="west")')
msg info "Removing peristent volumes"
kubectl delete pvc data-{north,west,east}-vault-{0..2}
msg info "Unsetting alias and function shortcuts"
unset north{0,1,2} n{0,1,2,a,s}
unset -f north{0..2} north{,-sh,-active,-stanbdy}
unset east{0,1,2} e{0,1,2,a,s}
unset -f east{0..2} east{,-sh,-active,-stanbdy}
unset west{0,1,2} w{0,1,2,a,s}
unset -f west{0..2} west{,-sh,-active,-stanbdy}

msg success "All clean!"
msg aloha "Make sure to close any lingering tunnels or proxies, and have a lovely day!"
