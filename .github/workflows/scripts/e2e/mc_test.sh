#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

LOG_PATH=.

function init_codegen() {
    # executed under path microservices-connector
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
   export YAML_DIR=$(pwd)/templates/MicroChatQnA
   kubectl apply -f $(pwd)/config/crd/bases/gmc.opea.io_gmconnectors.yaml
   kubectl apply -f $(pwd)/templates/MicroChatQnA/gmc-manager-rbac.yaml
   envsubst < $(pwd)/templates/MicroChatQnA/gmc-manager.yaml | kubectl apply -f -
   output=$(kubectl get pods -n system)
     # Check if the command was successful
   if [ $? -eq 0 ]; then
       echo "Successfully retrieved gmc controller information:"
       echo "$output"
   else
       echo "Failed to retrieve gmc controller information"
       exit 1
   fi
   # Wait until the pod is ready
   echo "Waiting for the pod to be ready..."
   max_retries=30
   retry_count=0
   while ! is_pod_ready control-plane gmc-controller; do
       if [ $retry_count -ge $max_retries ]; then
           echo "gmc-controller is not ready after waiting for a significant amount of time"
           exit 1
       fi
       echo "Pod is not ready yet. Retrying in 10 seconds..."
       sleep 10
       retry_count=$((retry_count + 1))
   done
   kubectl create ns gmcsample
   kubectl apply -f config/samples/chatQnA_v2.yaml
   output=$(kubectl get gmc -n gmcsample)
     # Check if the command was successful
   if [ $? -eq 0 ]; then
       echo "Successfully retrieved chantQnA  information:"
       echo "$output"
   else
       echo "Failed to retrieve chantQnA information"
       exit 1
    fi




}

function is_pod_ready() {
    local label_name=$1
    local label_value=$2 
    pod_status=$(kubectl get pods -l $label_name=$label_value -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
    if [ "$pod_status" == "True" ]; then
        return 0
    else
        return 1
    fi
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
