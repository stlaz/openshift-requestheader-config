# Simple HTPasswd Proxy For OpenShift Request Header IdP

The purpose of this repository is to provide a simple proof-of-concept
configuration script that sets up a login proxy that can be used as a
login proxy configured as the endpoint for OpenShift RequestHeader
identity provider.

## How to use this repository

1. `./config_requestheader.sh`
2. wait for the authentication operator to pick up the changes
3. `oc login --certificate-authority=./rootCA.crt -u franta -p dobryden`

## What this does

1. sets up an Apache HTTP container with custom configuration
   that uses an htpasswd file to authenticate users (the following
   are username/password combinations):

     - franta/dobryden
     - pepa/zdravim
     - josef/rankolide

2. sets up a CA, server and client certificates for the Apache HTTP
   server
3. configures OpenShift to trust the Apache HTTP server as its
   identity provider

## Is this a Red Hat supported solution?

No. This is only a proof of concept that serves as a good starting point
to understand how the RequestHeader identity provider works in OpenShift,
and possibly to show which certificate goes where.

## Why does this repository exist?

The RequestHeader identity provider is one of the harder ones to configure
configure correctly, but it is also the only one that can give your
organization a true SSO experience from both CLI and the browser. That is,
if you're using Kerberos to deal identities in your environment.
