#!/bin/bash

# pre-configure the endpoint to generate access tokens
. ./secret-vars.sh
if [ -n "$OAUTH_ACCESS_TOKEN_URL" ]; then
    echo "oauth_access_token_url: $OAUTH_ACCESS_TOKEN_URL" >> /meta/taupage.yaml
fi
if [ -n "$TOKEN_SERVICE_URL" ]; then
    echo "token_service_url: $TOKEN_SERVICE_URL" >> /meta/taupage.yaml
fi
if [ -n "$INSTANCE_LOGS_URL" ]; then
    echo "instance_logs_url: $INSTANCE_LOGS_URL" >> /meta/taupage.yaml
fi
if [ -n "$LOGSINK_USERNAME" ]; then
    echo "logsink_username: $LOGSINK_USERNAME" >> /meta/taupage.yaml
fi
if [ -n "$LOGSINK_PASSWORD" ]; then
    echo "logsink_password: $LOGSINK_PASSWORD" >> /meta/taupage.yaml
fi
if [ -n "$TOKENINFO_URL" ]; then
    echo "tokeninfo_url: $TOKENINFO_URL" >> /meta/taupage.yaml
fi
if [ -n "$UPSTREAM_TOKENINFO_URL" ]; then
    echo "upstream_tokeninfo_url: $UPSTREAM_TOKENINFO_URL" >> /meta/taupage.yaml
fi
if [ -n "$ACCESS_TOKEN_URL" ]; then
    echo "access_token_url: $ACCESS_TOKEN_URL" >> /meta/taupage.yaml
fi
if [ -n "$OPENID_PROVIDER_CONFIGURATION_URL" ]; then
    echo "openid_provider_configuration_url: $OPENID_PROVIDER_CONFIGURATION_URL" >> /meta/taupage.yaml
fi
if [ -n "$REVOCATION_PROVIDER_URL" ]; then
    echo "revocation_provider_url: $REVOCATION_PROVIDER_URL" >> /meta/taupage.yaml
fi
if [ -n "$TOKENINFO_BUSINESS_PARTNERS" ]; then
    echo "tokeninfo_business_partners: $TOKENINFO_BUSINESS_PARTNERS" >> /meta/taupage.yaml
fi
if [ -n "$TOKENINFO_ENABLE_INTROSPECTION" ]; then
    echo "tokeninfo_enable_introspection: $TOKENINFO_ENABLE_INTROSPECTION" >> /meta/taupage.yaml
fi
