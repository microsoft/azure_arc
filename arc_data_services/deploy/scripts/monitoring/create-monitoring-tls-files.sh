#!/bin/bash -e
NAMESPACE=$1
OUTPUT_DIR=$2

WORKING_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Fill in any missing variables
#
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=$(mktemp -d)
fi

# Create output dir if missing
#
if [ ! -d $OUTPUT_DIR ]; then
    mkdir $OUTPUT_DIR
fi

LOGSUI_CONF=$OUTPUT_DIR/logsui-ssl.conf
METRICSUI_CONF=$OUTPUT_DIR/metricsui-ssl.conf

sed "s|\${NAMESPACE}|${NAMESPACE}|g" $WORKING_DIR/logsui-ssl.conf.tmpl > $LOGSUI_CONF
sed "s|\${NAMESPACE}|${NAMESPACE}|g" $WORKING_DIR/metricsui-ssl.conf.tmpl > $METRICSUI_CONF

METRICSUI_CERT=$OUTPUT_DIR/metricsui-cert.pem
METRICSUI_KEY=$OUTPUT_DIR/metricsui-key.pem
LOGSUI_CERT=$OUTPUT_DIR/logsui-cert.pem
LOGSUI_KEY=$OUTPUT_DIR/logsui-key.pem

openssl genrsa -out $LOGSUI_KEY 2048 2>/dev/null
openssl req -nodes -x509 \
    -subj "/CN=logsui-svc" \
    -key $LOGSUI_KEY \
    -out $LOGSUI_CERT \
    -sha256 \
    -days 3650 \
    -config $LOGSUI_CONF \
    -extensions "v3_req"

openssl genrsa -out $METRICSUI_KEY 2048 2>/dev/null
openssl req -nodes -x509 \
    -subj "/CN=metricsui-svc" \
    -key $METRICSUI_KEY \
    -out $METRICSUI_CERT \
    -sha256 \
    -days 3650 \
    -config $METRICSUI_CONF \
    -extensions "v3_req"