kcn() {
    if [[ ${#} -le 0 || ${@[(r)--help]} ]]; then
        echo "usage: ${0} [--clear|--help] <context> [<namespace>]" >&2
        if [[ ! ${@[(r)--help]} ]]; then
            return 1
        else
            cat <<EOD >&2

  Manages KUBECTL_CONTEXT and KUBECTL_NAMESPACE variables
  for working with multiple Kubernetes clusters simultaneously.
  Requires an alias be set for kubectl to honor these variables.
  Add this to your .zshrc file.

  source <(kcn --alias)

examples:
  ${0} minikube      # change to default namespace in minikube context
  ${0} . kube-public # change namespace in current context
  ${0} --clear       # clear context and namespace variables
EOD
        fi
    elif [[ ${@[(r)--clear]} ]]; then
        unset KUBECTL_CONTEXT
        unset KUBECTL_NAMESPACE
    elif [[ ${@[(r)--alias]} ]]; then
# https://github.com/kubernetes/kubernetes/issues/27308#issuecomment-309207951
        cat <<\EOF
alias kubectl="kubectl \"--context=\${KUBECTL_CONTEXT:-\$(\kubectl config current-context)}\" \${KUBECTL_NAMESPACE/[[:alnum:]-]*/--namespace=\${KUBECTL_NAMESPACE}}"
EOF
    else
        alias kubectl >/dev/null || echo "warning: kubectl alias not installed; add 'source <(kcn --alias)' to .zshrc" >&2
        local _prev_context=${KUBECTL_CONTEXT}
        local _prev_namespace=${KUBECTL_NAMESPACE}
        local _context_list=($(\kubectl config view -o template \
            --template="{{range .contexts}}{{.name}} {{end}}"))
        if [[ ${1} == '.' ]]; then
            KUBECTL_CONTEXT=${KUBECTL_CONTEXT:-$(\kubectl config current-context)}
            KUBECTL_NAMESPACE=${KUBECTL_NAMESPACE:-default}
        elif [[ ! ${_context_list[(r)${1}]} ]]; then
            echo "error: context ${1} not found" >&2
            return 2
        else
            KUBECTL_CONTEXT=${1}
            KUBECTL_NAMESPACE=${KUBECTL_NAMESPACE:-default}
        fi

        if [[ -n ${2} ]]; then
            local _namespace_list=($(\kubectl --context=${KUBECTL_CONTEXT} \
                get namespaces -o template \
                --template="{{range .items}}{{.metadata.name}} {{end}}"))
            if [[ ! ${_namespace_list[(r)$2]} ]]; then
                echo "error: namespace ${2} not found in context ${KUBECTL_CONTEXT}" >&2
                KUBECTL_CONTEXT=${_prev_context}
                KUBECTL_NAMESPACE=${_prev_namespace}
                return 3
            else
                KUBECTL_NAMESPACE=${2}
            fi
        fi
    fi
}

_kcn() {
    _arguments '--clear[clear context/namespace]' '--help[show usage]' ':context:->context' ':namespace:->namespace'
    case ${state} in
        context)
            local context_list=($(\kubectl config view -o template \
                --template="{{range .contexts}}{{.name}} {{end}}" 2>/dev/null))
            _values 'context' ${context_list}
            ;;
        namespace)
            local context=${words[2]}
            if [[ ${context} == '.' ]]; then
                context=${KUBECTL_CONTEXT}
            fi
            local namespace_list=($(\kubectl --context=${context} get namespaces -o template \
                --template="{{range .items}}{{.metadata.name}} {{end}}" 2>/dev/null))
            _values 'namespace' ${namespace_list}
            ;;
    esac
}

compdef _kcn kcn