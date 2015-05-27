# pre-configure the endpoint to generate access tokens
. ./secret-vars.sh
if [ -n "$TOKEN_SERVICE_URL" ]; then
    echo "token_service_url: $TOKEN_SERVICE_URL" >> /etc/taupage.yaml
fi
if [ -n "$INSTANCE_LOGS_URL" ]; then
    echo "instance_logs_url: $INSTANCE_LOGS_URL" >> /etc/taupage.yaml
fi
