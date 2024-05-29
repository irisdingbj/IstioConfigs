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
   kubectl apply -f $(pwd)/config/samples/chatQnA_v2.yaml
   
   # Wait until the chatqa gmc custom resource is ready
   echo "Waiting for the chatqa gmc custom resource to be ready..."
   while ! is_gmc_ready; do
       if [ $retry_count -ge $max_retries ]; then
           echo "chatqa gmc custom resource is not ready after waiting for a significant amount of time"
           exit 1
       fi
       echo "chatqa gmc custom resource is not ready yet. Retrying in 10 seconds..."
       sleep 10
       output=$(kubectl get gmc -n gmcsample)
        # Check if the command was successful
       if [ $? -eq 0 ]; then
         echo "Successfully retrieved chatqa gmc custom resource information:"
         echo "$output"
       else
         echo "Failed to retrieve chatqa gmc custom resource information"
         exit 1
       fi
       retry_count=$((retry_count + 1))
   done
   accessUrl=$(get_gmc_accessURL)
   echo $accessUrl
   output=$(kubectl get pods -n gmcsample)
   echo $output

   # deploy client pod for testing
   kubectl apply -f $(pwd)/test/client/sleep.yaml
   
   # send request to chatqnA 
   export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
   kubectl exec -it "$SLEEP_POD" -- curl -s $accessUrl -H "Content-Type: application/json" -d '{
        "messages": "What is the revenue of Nike in 2023?"}' > ${LOG_PATH}/curl_chatqna.log
   echo "Checking response results, make sure the output is reasonable. "
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
    accessUrl=$(kubectl get gmc -n gmcsample -o jsonpath="{.items[?(@.metadata.name=='chatqa')].status.accessUrl}")
    echo $accessUrl
}


function validate_codegen() {

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
        ;;
    *)
        echo "Unknown function: $1"
        ;;
esac
