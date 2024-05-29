#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

LOG_PATH=.

function init_codegen() {
    # executed under path helm-charts/codegen
    # init var
   output=$(kubectl get pods)

   # Check if the command was successful
   if [ $? -eq 0 ]; then
       echo "Successfully retrieved pods information:"
       echo "$output"
   else
       echo "Failed to retrieve pods information"
       exit 1
   fi
   
   pp=$(pwd)

   # Check if the command was successful
   if [ $? -eq 0 ]; then
       echo "Successfully list file info:"
       echo "$pp"
   else
       echo "Failed to list file information"
       exit 1
   fi
   
   echo $LOG_PATH
   export YAML_DIR=$LOG_PATH/samples/MicroChatQnA
   kubectl apply -f $LOG_PATH/config/crd/bases/gmc.opea.io_gmconnectors.yaml

}

function init_chatqna() {
    echo "Init chatqna"
    kubectl 
}

function validate_codegen() {
    ip_address=$(kubectl get svc $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    port=$(kubectl get svc $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
    # Curl the Mega Service
    curl http://${ip_address}:${port}/v1/codegen -H "Content-Type: application/json" -d '{
        "model": "ise-uiuc/Magicoder-S-DS-6.7B",
        "messages": "Implement a high-level API for a TODO list application. The API takes as input an operation request and updates the TODO list in place. If the request is invalid, raise an exception."}' > curl_megaservice.log

    echo "Checking response results, make sure the output is reasonable. "
    local status=true
    if [[ -f curl_megaservice.log ]] && \
    [[ $(grep -c "billion" curl_megaservice.log) != 0 ]]; then
        status=true
    fi

    if [ $status == false ]; then
        echo "Response check failed, please check the logs in artifacts!"
    else
        echo "Response check succeed!"
    fi
}

function validate_chatqna() {
    ip_address=$(kubectl get svc $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    port=$(kubectl get svc $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
    # Curl the Mega Service
    curl http://${ip_address}:${port}/v1/chatqna -H "Content-Type: application/json" -d '{
        "model": "Intel/neural-chat-7b-v3-3",
        "messages": "What is the revenue of Nike in 2023?"}' > ${LOG_PATH}/curl_megaservice.log
    exit_code=$?

    echo "Checking response results, make sure the output is reasonable. "
    local status=false
    if [[ -f $LOG_PATH/curl_megaservice.log ]] && \
    [[ $(grep -c "billion" $LOG_PATH/curl_megaservice.log) != 0 ]]; then
        status=true
    fi

    if [ $status == false ]; then
        echo "Response check failed, please check the logs in artifacts!"
        exit 1
    else
        echo "Response check succeed!"
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <function_name>"
    exit 1
fi

case "$1" in
    init_codegen)
        pushd helm-charts/codegen
        init_codegen
        popd
        ;;
    validate_codegen)
        RELEASE_NAME=$2
        NAMESPACE=$3
        validate_codegen
        ;;
    init_chatqna)
        pushd helm-charts/chatqna
        init_chatqna
        popd
        ;;
    validate_chatqna)
        RELEASE_NAME=$2
        NAMESPACE=$3
        validate_chatqna
        ;;
    *)
        echo "Unknown function: $1"
        ;;
esac
