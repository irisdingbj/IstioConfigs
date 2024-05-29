#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

LOG_PATH=.

function verify_chatqna() {
   # executed under path microservices-connector
   export YAML_DIR=$(pwd)/templates/MicroChatQnA
   kubectl apply -f $(pwd)/config/crd/bases/gmc.opea.io_gmconnectors.yaml
   kubectl apply -f $(pwd)/templates/MicroChatQnA/gmc-manager-rbac.yaml
   envsubst < $(pwd)/templates/MicroChatQnA/gmc-manager.yaml | kubectl apply -f -
   # Wait until the gmc conroller pod is ready
   echo "Waiting for the pod to be ready..."
   max_retries=30
   retry_count=0
   while ! is_gmccontroller_ready; do
       if [ $retry_count -ge $max_retries ]; then
           echo "gmc-controller is not ready after waiting for a significant amount of time"
           exit 1
       fi
       echo "gmc-controller is not ready yet. Retrying in 10 seconds..."
       sleep 10
       output=$(kubectl get pods -n system)
        # Check if the command was successful
       if [ $? -eq 0 ]; then
         echo "Successfully retrieved gmc controller information:"
         echo "$output"
       else
         echo "Failed to retrieve gmc controller information"
         exit 1
       fi
       retry_count=$((retry_count + 1))
   done
   # Deploy chatQnA sample
   kubectl create ns gmcsample
   kubectl apply -f config/samples/chatQnA_v2.yaml
   while ! is_gmc_ready; do
       if [ $retry_count -ge $max_retries ]; then
           echo "chatQnA gmc is not ready after waiting for a significant amount of time"
           exit 1
       fi
       echo "chatQnA gmc is not ready yet. Retrying in 10 seconds..."
       sleep 10
       output=$(kubectl get gmc -n gmcsample)
        # Check if the command was successful
       if [ $? -eq 0 ]; then
         echo "Successfully retrieved gmc controller information:"
         echo "$output"
       else
         echo "Failed to retrieve gmc controller information"
         exit 1
       fi
       retry_count=$((retry_count + 1))
   done
   accessUrl=$(get_gmc_accessURL)
   echo $accessUrl
   output=$(kubectl get pods -n gmcsample)
   echo $output
}

function is_gmccontroller_ready() {
    pod_status=$(kubectl get pods -n system -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
    if [ "$pod_status" == "True" ]; then
        return 0
    else
        return 1
    fi
}
function is_gmc_ready() {
    ready_status=$(kubectl get gmc -n gmcsample -o jsonpath="{.items[?(@.metadata.name=='chatqa')].status.status}")
    if [ "$ready_status" == "Success" ]; then
        return 0
    else
        return 1
    fi
}
function get_gmc_accessURL() {
    accessUrl=$(kubectl get gmc -n gmcsample -o jsonpath="{.items[?(@.metadata.name=='codegen')].status.accessUrl}")
    echo $accessUrl
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
        pushd microservices-connector
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
