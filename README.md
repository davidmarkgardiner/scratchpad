# Kyverno Policy Failure Alerts

This document provides a collection of Prometheus queries that can be used to create alerts for Kyverno policy failures in your Kubernetes cluster.

## Overview

Kyverno is a policy engine designed for Kubernetes that validates, mutates, and generates configurations using admission controls and background scans. When policies fail, it's important to be alerted so you can take appropriate action.

## Prometheus Alert Queries

### High Severity Policy Failures

```promql
# Alert on any high severity policy failures
sum(kyverno_policy_results{status="fail", severity="high"}) > 0

# Alert on high severity policy failures in production namespaces
sum(kyverno_policy_results{status="fail", severity="high", namespace=~"prod.*"}) > 0
```

### Critical Policy Failures by Category

```promql
# Alert on security category policy failures
sum(kyverno_policy_results{status="fail", category="security"}) > 0

# Alert on pod security policy failures
sum(kyverno_policy_results{status="fail", policy=~"pod-security.*"}) > 0
```

### Namespace-Specific Policy Failures

```promql
# Alert on any policy failures in specific namespaces
sum(kyverno_policy_results{status="fail", namespace=~"(kube-system|default)"}) > 0
```

### Policy Failure Rate

```promql
# Alert when policy failure rate exceeds threshold (e.g., 5%)
(sum(kyverno_policy_results{status="fail"}) / sum(kyverno_policy_results)) * 100 > 5
```

### Specific Policy Failures

```promql
# Alert on failures of specific critical policies
sum(kyverno_policy_results{status="fail", policy="require-pod-probes"}) > 0
sum(kyverno_policy_results{status="fail", policy="restrict-image-registries"}) > 0
sum(kyverno_policy_results{status="fail", policy="require-pod-requests-limits"}) > 0
```

### Admission Controller Failures

```promql
# Alert on admission controller failures
sum(rate(kyverno_admission_review_duration_seconds_count{status="fail"}[5m])) > 0
```

### Policy Execution Errors

```promql
# Alert on policy execution errors
sum(rate(kyverno_policy_execution_duration_seconds_count{status="error"}[5m])) > 0
```

### Controller Issues

```promql
# Alert on controller drops (indicates unrecoverable errors)
sum(rate(kyverno_controller_drops_total[5m])) > 0

# Alert on high controller requeue rate
sum(rate(kyverno_controller_requeues_total[5m])) > 10
```

### Cleanup Controller Errors

```promql
# Alert on cleanup controller errors
sum(rate(kyverno_cleanup_controller_errors_total[5m])) > 0
```

## Policy Reporter Integration

If you're using Policy Reporter with Kyverno, you can use these additional queries:

```promql
# Alert on policy failures by severity and category
policy_report_result{status="fail", severity="high"} > 0
policy_report_result{status="fail", category="security"} > 0

# Alert on specific policy failures
policy_report_result{status="fail", policy="require-pdb"} > 0
```

## Setting Up Alerts in Prometheus

To set up these alerts in Prometheus, create a PrometheusRule custom resource:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kyverno-alerts
  namespace: monitoring
spec:
  groups:
  - name: kyverno.rules
    rules:
    - alert: KyvernoHighSeverityPolicyFailure
      expr: sum(kyverno_policy_results{status="fail", severity="high"}) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High severity Kyverno policy failures detected"
        description: "There are {{ $value }} high severity policy failures in the cluster"
        
    - alert: KyvernoSecurityPolicyFailure
      expr: sum(kyverno_policy_results{status="fail", category="security"}) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Security policy failures detected"
        description: "There are {{ $value }} security policy failures in the cluster"
```

## Recommended Alerting Thresholds

| Alert | Threshold | Severity | Description |
|-------|-----------|----------|-------------|
| High Severity Policy Failures | > 0 | Critical | Any high severity policy failure |
| Security Policy Failures | > 0 | Critical | Any security policy failure |
| Pod Security Policy Failures | > 0 | Critical | Any pod security policy failure |
| Policy Failure Rate | > 5% | Warning | Overall policy failure rate exceeds 5% |
| Controller Drops | > 0 | Warning | Kyverno controller is dropping items |
| Cleanup Controller Errors | > 0 | Warning | Errors in cleanup controller |

## Additional Resources

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kyverno Monitoring](https://kyverno.io/docs/monitoring/)
- [Policy Reporter](https://kyverno.github.io/policy-reporter/) 