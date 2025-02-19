Here's a comprehensive set of useful kubectl aliases! Add these to your `.zshrc`:

```bash
# Kubectl main aliases
alias k='kubecolor'
alias kd='kubecolor describe'
alias kg='kubecolor get'

# Pod operations
alias kgp='kubecolor get pods'
alias kgpa='kubecolor get pods --all-namespaces'
alias kdp='kubecolor describe pod'
alias kl='kubecolor logs'
alias klf='kubecolor logs -f'
alias kcp='kubecolor cp'
alias kgpw='kubecolor get pods -o wide'
alias kgpwatch='watch kubectl get pods'

# Deployment operations
alias kgd='kubecolor get deployments'
alias kdd='kubecolor describe deployment'
alias ksd='kubecolor scale deployment'
alias krd='kubecolor rollout deployment'
alias krh='kubecolor rollout history'
alias krs='kubecolor rollout status'
alias kru='kubecolor rollout undo'

# Service operations
alias kgs='kubecolor get svc'
alias kds='kubecolor describe service'

# Namespace operations
alias kgns='kubecolor get namespaces'
alias kens='kubens'
alias kcn='kubecolor config set-context --current --namespace'

# Config and context
alias kgc='kubecolor config get-contexts'
alias kcc='kubecolor config current-context'
alias kx='kubectx'

# Node operations
alias kgno='kubecolor get nodes'
alias kdno='kubecolor describe node'
alias kgrow='kubecolor get nodes -o wide'

# Events and logs
alias kge='kubecolor get events --sort-by=.metadata.creationTimestamp'
alias kgel='kubecolor get events --sort-by=.metadata.creationTimestamp | grep -i "error\|warn"'

# Resource operations
alias kga='kubecolor get all'
alias kgaa='kubecolor get all --all-namespaces'
alias kgsc='kubecolor get storageclass'
alias kgpv='kubecolor get pv'
alias kgpvc='kubecolor get pvc'

# Custom formatted outputs
alias kgpjson='kubecolor get pods -o json'
alias kgpyaml='kubecolor get pods -o yaml'

# Watch commands
alias kgpw='watch kubectl get pods'
alias kgnw='watch kubectl get nodes'
alias kgsw='watch kubectl get services'

# Logs with stern
alias kls='stern'
alias klsp='stern -n production'
alias klsd='stern -n development'

# Debug and troubleshooting
alias kdebug='kubectl run -i --tty --rm debug --image=ubuntu -- bash'
alias knrunning='kubectl get pods --field-selector=status.phase!=Running'
alias kfails='kubectl get pods --field-selector=status.phase==Failed'
```

Some useful functions to add as well:
```bash
# Get logs from all containers in a pod
klogs() {
    for container in $(kubectl get pods $1 -o jsonpath='{.spec.containers[*].name}'); do
        echo "=== Logs for container $container ==="
        kubectl logs $1 -c $container
    done
}

# Get all resources in a namespace
kgetall() {
    namespace=${1:-default}
    for resource in $(kubectl api-resources --verbs=list --namespaced -o name); do
        echo "=== $resource ==="
        kubectl -n $namespace get $resource
    done
}

# Follow logs from multiple pods
klogsf() {
    kubectl get pods -l $1 --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl logs -f {} &
}
```

Usage examples:
```bash
# Get logs from a pod with multiple containers
klogs my-pod-name

# Get all resources in production namespace
kgetall production

# Follow logs from all pods with label app=nginx
klogsf "app=nginx"

# Watch pods in real-time
kgpw

# Get events with errors
kgel
```

Would you like me to explain any of these aliases in more detail or add more specific ones for your workflow?
