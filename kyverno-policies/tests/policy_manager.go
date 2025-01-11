package tests

import (
	"context"
	"fmt"

	kyvernov1 "github.com/kyverno/kyverno/api/kyverno/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

type PolicyManager struct {
	client client.Client
}

func NewPolicyManager(c client.Client) *PolicyManager {
	return &PolicyManager{client: c}
}

func (pm *PolicyManager) CleanupPolicies(ctx context.Context) error {
	policies := []string{
		"mutate-ns-deployment-spotaffinity",
		"require-resource-limits",
		"validate-ns-istio-injection",
		"mutate-cluster-namespace-istiolabel",
		"audit-cluster-peerauthentication-mtls",
	}

	for _, name := range policies {
		policy := &kyvernov1.ClusterPolicy{
			ObjectMeta: metav1.ObjectMeta{
				Name: name,
			},
		}
		if err := pm.client.Delete(ctx, policy); err != nil {
			return err
		}
	}
	return nil
}

func (pm *PolicyManager) ApplyProductionPolicies(ctx context.Context) error {
	policies := []kyvernov1.ClusterPolicy{
		{
			ObjectMeta: metav1.ObjectMeta{
				Name: "mutate-ns-deployment-spotaffinity-prod",
			},
			Spec: kyvernov1.Spec{
				// Copy spec from your YAML file
			},
		},
		{
			ObjectMeta: metav1.ObjectMeta{
				Name: "require-resource-limits-prod",
			},
			Spec: kyvernov1.Spec{
				// Copy spec from your YAML file
			},
		},
		// Add other policies...
	}

	for _, policy := range policies {
		if err := pm.client.Create(ctx, &policy); err != nil {
			return fmt.Errorf("failed to create policy %s: %v", policy.Name, err)
		}
	}

	return nil
}
