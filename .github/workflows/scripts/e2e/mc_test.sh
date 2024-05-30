#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

LOG_PATH=.

function validate_chatqna() {
   # executed under path microservices-connector
   # Deploy GMC CRD and controller
   export YAML_DIR=$(pwd)/templates/MicroChatQnA
   kubectl apply -f $(pwd)/config/crd/bases/gmc.opea.io_gmconnectors.yaml
   kubectl apply -f $(pwd)/templates/MicroChatQnA/gmc-manager-rbac.yaml
   kubectl create configmap gmcyaml -n system --from-file $(pwd)/templates/MicroChatQnA
   kubectl apply -f $(pwd)/templates/MicroChatQnA/gmc-manager.yaml
   
   # Wait until the gmc conroller pod is ready
   wait_until_pod_ready "gmc-controller" "system" "gmc-controller"


   # Check controller logs
   export Controller_POD=$(kubectl get pod -n system -o jsonpath={.items..metadata.name})

   # Deploy chatQnA sample
   kubectl create ns chatqa
   kubectl apply -f $(pwd)/config/samples/chatQnA_v2.yaml
   kubectl apply -f $(pwd)/templates/MicroChatQnA/gmc-rbac.yaml -n chatqa
   kubectl get sa -n chatqa
   kubectl apply -f $(pwd)/templates/MicroChatQnA/gmc-secret.yaml -n chatqa


   # get accessURL for chatqa
   accessUrl=$(get_gmc_accessURL)
   echo $accessUrl
   output=$(kubectl get pods -n chatqa)
   echo $output

   # Wait until the router service is ready
   echo "Waiting for the chatqa router service to be ready..."
   wait_until_pod_ready "chatqna router" "chatqa" "router-service"
   kubectl get events -n chatqa

 

   # deploy client pod for testing
   kubectl apply -f $(pwd)/test/client/sleep.yaml

   # wait for client pod ready
   wait_until_pod_ready "sleep" "default" "sleep"

   kubectl logs $Controller_POD -n system

   # send request to chatqnA 
   export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
   echo "$SLEEP_POD"
   kubectl exec "$SLEEP_POD" -- curl $accessUrl -X POST -H "Content-Type: application/json" -d '{
        "text": "What is the revenue of Nike in 2023?"}' > ${LOG_PATH}/curl_chatqna.log
   echo "Checking response results, make sure the output is reasonable. "
   export ROUTER_POD=$(kubectl get pod -l app=router-service -n chatqa -o jsonpath={.items..metadata.name})
   kubectl logs $ROUTER_POD -n chatqa
   local status=false
   if [[ -f $LOG_PATH/curl_chatqna.log ]] && \
   [[ $(grep -c "billion" $LOG_PATH/curl_chatqna.log) != 0 ]]; then
      status=true
   fi
   if [ $status == false ]; then
      echo "Response check failed, please check the logs in artifacts!"
      exit 1
   else
      echo "Response check succeed!"
   fi  
}



function wait_until_pod_ready() {
    echo "Waiting for the $1 to be ready..."
    max_retries=30
    retry_count=0
    while ! is_pod_ready $2 $3; do
        if [ $retry_count -ge $max_retries ]; then
            echo "$1 is not ready after waiting for a significant amount of time"
            exit 1
        fi
        echo "$1 is not ready yet. Retrying in 10 seconds..."
        sleep 10
        output=$(kubectl get pods -n $2)
        # Check if the command was successful
        if [ $? -eq 0 ]; then
          echo "Successfully retrieved $1 information:"
          echo "$output"
        else
          echo "Failed to retrieve $1 information"
          exit 1
        fi
        retry_count=$((retry_count + 1))
    done
}

function is_pod_ready() {
    if [ "$2" == "gmc-controller" ]; then
      pod_status=$(kubectl get pods -n $1 -o jsonpath='{.items[].status.conditions[?(@.type=="Ready")].status}')
    else
      pod_status=$(kubectl get pods -n $1 -l app=$2 -o jsonpath='{.items[].status.conditions[?(@.type=="Ready")].status}')
    fi
    if [ "$pod_status" == "True" ]; then
        return 0
    else
        return 1
    fi
}

function get_gmc_accessURL() {
    accessUrl=$(kubectl get gmc -n chatqa -o jsonpath="{.items[?(@.metadata.name=='chatqa')].status.accessUrl}")
    echo $accessUrl
}

function validate_codegen() {
    echo "todo"
}


if [ $# -eq 0 ]; then
    echo "Usage: $0 <function_name>"
    exit 1
fi

case "$1" in
    validate_chatqna)
        pushd microservices-connector
        validate_chatqna
        popd
        ;;
    validate_codegen)
        pushd microservices-connector
        validate_codegen
        popd
        ;;
    *)
        echo "Unknown function: $1"
        ;;
esac
