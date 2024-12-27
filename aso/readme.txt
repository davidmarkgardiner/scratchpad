cat operator.yaml | sed 's/--crd-pattern=.*/--crd-pattern=containerservice.azure.com\/*/' | kubectl apply -f -
# Filter and apply only containerservice CRDs
kubectl apply -f <(cat azureserviceoperator_customresourcedefinitions_v2.0.0.yaml | awk '/apiVersion: apiextensions.k8s.io\/v1/{p=1;print;next} /^---$/{if(p){print}p=0;next} p{print}' | grep -A10000 -B10000 "containerservice.azure.com")
