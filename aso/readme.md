cat operator.yaml | sed 's/--crd-pattern=.*/--crd-pattern=containerservice.azure.com\/*/' | kubectl apply -f -
