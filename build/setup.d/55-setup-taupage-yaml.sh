# pre-configure the endpoint to generate access tokens
. ./secret-vars.sh
if [ -n "$TOKEN_SERVICE_URL" ]; then
    echo "token_service_url: $TOKEN_SERVICE_URL" >> /etc/taupage.yaml
fi
