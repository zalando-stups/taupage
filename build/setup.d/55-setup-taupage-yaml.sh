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
