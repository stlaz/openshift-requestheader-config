#!/bin/bash
set -e

PASSWORD=${PASSWORD:-password}
DIR="$( dirname "${BASH_SOURCE[0]}")"

function create_ca() {
    # gen cert/key pair for CA, use password to secure the key because why not
    openssl genrsa -aes256 -passout "pass:$PASSWORD" -out "${DIR}/rootCA.key" 4096
    openssl req -x509 -new -nodes -key "${DIR}/rootCA.key" \
        -sha512 -days 3655 -out "${DIR}/rootCA.crt" \
        -subj "/C=CZ/ST=Moravia/O=My Private Org Ltd./CN=Test CA" \
        -extensions v3_ca -config "${DIR}/custom.cnf" \
        -passin "pass:${PASSWORD}"
}

function create_client() {
    # generate cert/key pair for client auth, let's omit password for simplicity of use
    openssl genrsa -out "${DIR}/client.key" 4096
    openssl req -new -sha256 -key "${DIR}/client.key" \
        -subj "/C=CZ/ST=Moravia/O=My Private Org Ltd./CN=somewhere.com" \
        -out "${DIR}/client.csr"

    openssl x509 -req -in "${DIR}/client.csr" -CA "${DIR}/rootCA.crt" \
        -CAkey "${DIR}/rootCA.key" -CAcreateserial -out "${DIR}/client.crt" \
        -days 1024 -sha256 -extfile "${DIR}/custom.cnf" -extensions client_auth \
        -passin "pass:${PASSWORD}"
}

function create_server() {
    server_name=${1:-somewhere.com}
    # generate cert/key pair for server, let's omit password for simplicity of use
    openssl genrsa -out "${DIR}/server.key" 4096
    openssl req -new -sha256 -key "${DIR}/server.key" \
        -subj "/CN=${server_name}" \
        -out "${DIR}/server.csr"

    openssl x509 -req -in "${DIR}/server.csr" -CA "${DIR}/rootCA.crt" \
        -CAkey "${DIR}/rootCA.key" -CAcreateserial -out "${DIR}/server.crt" \
        -days 1024 -sha256 -extfile "${DIR}/custom.cnf" -extensions server_auth \
        -passin "pass:${PASSWORD}"
}

function config_requestheader_idp() {
    DOMAIN=$(oc get ingresscontroller.operator -n openshift-ingress-operator default -o template='{{ .status.domain }}')
    DOMAIN_WILDCARD="*.$DOMAIN"
    export SAN="DNS:$DOMAIN_WILDCARD"
    create_ca
    create_server "$DOMAIN_WILDCARD"
    create_client

    oc new-project login-proxy || true
    oc adm policy add-cluster-role-to-user cluster-admin -z default -n login-proxy || true

    oc get cm -n openshift-config-managed default-ingress-cert -o template='{{ index .data "ca-bundle.crt"}}' > router-ca.crt
    cat rootCA.crt router-ca.crt > ultimateca.crt

    cat client.{crt,key} > client.pem

    oc create cm request-header-ca --from-file="ca.crt=${DIR}/rootCA.crt" -n openshift-config
    oc create secret generic crypto --from-file=server.crt --from-file=server.key --from-file=client.pem --from-file=ca.crt=ultimateca.crt

    oc apply -f "${DIR}/apache_login_proxy.yaml"

    OAUTH_ROUTE=$(oc get route -n openshift-authentication oauth-openshift -o template='{{ .spec.host }}')
    PROXY_ROUTE=$(oc get route -n login-proxy login -o template='{{ .spec.host }}')
    oc create cm routes --from-literal=oauth_route="$OAUTH_ROUTE" --from-literal=proxy_route="$PROXY_ROUTE"

    oc apply -f - <<< $(cat requestheaderidp.yaml | sed -e "s#\${PROXY_ROUTE}#${PROXY_ROUTE}#g")
}

config_requestheader_idp
