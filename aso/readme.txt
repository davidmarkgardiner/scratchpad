cat operator.yaml | sed 's/--crd-pattern=.*/--crd-pattern=containerservice.azure.com\/*/' | kubectl apply -f -
cat operator.yaml | sed 's/--crd-pattern=.*/--crd-pattern=containerservice.azure.com\/*/' | kubectl apply -f -

# Filter and apply only containerservice CRDs
kubectl apply -f <(cat azureserviceoperator_customresourcedefinitions_v2.0.0.yaml | awk '/apiVersion: apiextensions.k8s.io\/v1/{p=1;print;next} /^---$/{if(p){print}p=0;next} p{print}' | grep -A10000 -B10000 "containerservice.azure.com")


kubectl get crd managedclustersagentpools.containerservice.azure.com -o jsonpath='{.spec.versions[*].name}' | cat
v1api20210501 v1api20210501storage v1api20230201 v1api20230201storage v1api20231001 v1api20231001storage v1api20231102preview v1api20231102previewstorage v1api20240402preview v1api20240402previewstorage v1api202409
