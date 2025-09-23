You have access to a local Kubernetes cluster that has Kiberno running. There's a policy located. /blob/policy.yaml

This policy is blocking all deployments that have no label set regardless if it's setting the Istio label or not. How can we fix this policy so it only applies to deployments that have the Istio label set and not just block deployments that have no label set?

Test this with a couple of deployments:
1. One with a label
2. One without  to make sure it's working.


also fic this error - 
➜ kaf blog/kyverno/policy.yaml                                                               
Error from server (InternalError): error when creating "blog/kyverno/policy.yaml": Internal error occurred: failed calling webhook "mutate-policy.kyverno.svc": failed to call webhook: Post "https://kyverno-svc.kyverno.svc:443/policymutate?timeout=10s": context deadline exceeded