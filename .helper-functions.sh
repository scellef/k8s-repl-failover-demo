# Colors because the world is a colorful place 🌎
TXTRED="$(tput setaf 1)"
TXTGRN="$(tput setaf 2)"
TXTYLW="$(tput setaf 3)"
TXTBLU="$(tput setaf 4)"
TXTMGT="$(tput setaf 5)"
TXTCYA="$(tput setaf 6)"
TXTWHT="$(tput setaf 7)"
TXTRST="$(tput sgr0)"

msg() {
    MSGSRC="[k8s-repl-demo]"
    MSGTYPE="$1"
    MSGTXT="$2"
    case "${MSGTYPE}" in
        aloha)
            printf "%s%s [=] %s %s\\n" "$TXTBLU" "$MSGSRC" "$MSGTXT" "$TXTRST"
            ;;
        info)
            printf "%s%s [-] %s %s\\n" "$TXTCYA" "$MSGSRC" "$MSGTXT" "$TXTRST"
            ;;
        success)
            printf "%s%s [+] %s %s\\n" "$TXTGRN" "$MSGSRC" "$MSGTXT" "$TXTRST"
            ;;
        warn)
            >&2 printf "%s%s [?] %s %s\\n" "$TXTYLW" "$MSGSRC" "$MSGTXT" "$TXTRST"
            ;;
        error)
            >&2 printf "%s%s [!] %s %s\\n" "$TXTRED" "$MSGSRC" "$MSGTXT" "$TXTRST"
            ;;
        *)
            >&2 printf "%s%s [@] %s %s\\n" "$TXTCYA" "$MSGSRC" "$MSGTXT" "$TXTRST"
            ;;
    esac
}

check_deps() {
  [ "$(basename $(which jq))" == "jq" ] || \
    (msg error "Missing dependency 'jq'! Please ensure it's in your \$PATH" ; exit)
  [ "$(basename $(which helm))" == "helm" ] || \
    (msg error "Missing dependency 'helm'! Please ensure it's in your \$PATH" ; exit)
  [ "$(basename $(which kubectl))" == "kubectl" ] || \
    (msg error "Missing dependency 'kubectl'! Please ensure it's in your \$PATH" ; exit)
}

cleanup_int() {
  echo
  msg warn "Caught interrupt!  Cleaning up..."
  helm uninstall $(helm list -o json | jq -r '.[].name | select(.=="unseal"//.=="north"//.=="east"//.=="west")')
  kubectl delete pvc data-{north,west,east}-vault-{0..2}
  msg notice "Exiting..."
  exit
}
