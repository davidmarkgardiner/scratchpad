package tests

import (
	"context"
	"testing"
	"time"

	kyvernov1 "github.com/kyverno/kyverno/api/kyverno/v1"
	securityv1beta1 "istio.io/api/security/v1beta1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

func setupTestEnvironment(t *testing.T) (client.Client, *kubernetes.Clientset, func()) {
	// Load kubernetes config
	config, err := clientcmd.BuildConfigFromFlags("", clientcmd.RecommendedHomeFile)
	if err != nil {
		t.Fatalf("Error building kubeconfig: %v", err)
	}

	// Create clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		t.Fatalf("Error creating kubernetes client: %v", err)
	}

	// Create controller-runtime client
	c, err := client.New(config, client.Options{})
	if err != nil {
		t.Fatalf("Error creating controller-runtime client: %v", err)
	}

	// Return cleanup function
	cleanup := func() {
		ctx := context.Background()
		// Delete test namespaces
		namespaces := []string{
			"test-spot",
			"test-istio",
			"test-istio-rev",
			"test-limits",
		}
		for _, ns := range namespaces {
			err := clientset.CoreV1().Namespaces().Delete(ctx, ns, metav1.DeleteOptions{})
			if err != nil {
				t.Logf("Error cleaning up namespace %s: %v", ns, err)
			}
		}
	}

	return c, clientset, cleanup
}

func TestSpotAffinityPolicy(t *testing.T) {
	c, clientset, cleanup := setupTestEnvironment(t)
	defer cleanup()

	ctx := context.Background()

	// Create test namespace
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-spot",
			Labels: map[string]string{
				"worker-type":     "spot",
				"istio-injection": "disabled",
				"test-policy":     "spot-affinity",
			},
		},
	}
	if err := c.Create(ctx, ns); err != nil {
		t.Fatalf("Failed to create test namespace: %v", err)
	}

	// Create test deployment
	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-deployment",
			Namespace: "test-spot",
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": "test-app",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":             "test-app",
						"istio-injection": "disabled",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "nginx",
							Image: "nginx:latest",
							Resources: corev1.ResourceRequirements{
								Limits: corev1.ResourceList{
									"cpu":    resource.MustParse("100m"),
									"memory": resource.MustParse("128Mi"),
								},
							},
						},
					},
				},
			},
		},
	}

	if err := c.Create(ctx, deployment); err != nil {
		t.Fatalf("Failed to create test deployment: %v", err)
	}

	// Wait for mutation
	time.Sleep(10 * time.Second)

	// Check deployment configuration
	mutatedDeployment := &appsv1.Deployment{}
	if err := c.Get(ctx, client.ObjectKey{Namespace: "test-spot", Name: "test-deployment"}, mutatedDeployment); err != nil {
		t.Fatalf("Failed to get mutated deployment: %v", err)
	}

	// Verify spot configuration
	if !hasSpotToleration(mutatedDeployment) {
		t.Error("Spot toleration not found")
	}

	if !hasPodAntiAffinity(mutatedDeployment) {
		t.Error("Pod anti-affinity not found")
	}

	if !hasNodeAffinity(mutatedDeployment) {
		t.Error("Node affinity for spot instances not found")
	}
}

func TestResourceLimitsPolicy(t *testing.T) {
	c, clientset, cleanup := setupTestEnvironment(t)
	defer cleanup()

	ctx := context.Background()

	// Create test namespace
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-limits",
			Labels: map[string]string{
				"istio-injection": "disabled",
				"test-policy":     "resource-limits",
			},
		},
	}
	if err := c.Create(ctx, ns); err != nil {
		t.Fatalf("Failed to create test namespace: %v", err)
	}

	// Test deployment without resource limits
	deploymentNoLimits := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-deployment-no-limits",
			Namespace: "test-limits",
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": "test-app",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":             "test-app",
						"istio-injection": "disabled",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "nginx",
							Image: "nginx:latest",
						},
					},
				},
			},
		},
	}

	// This should fail
	err := c.Create(ctx, deploymentNoLimits)
	if err == nil {
		t.Error("Expected policy to deny deployment without resource limits")
	}

	// Test deployment with resource limits
	deploymentWithLimits := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-deployment-with-limits",
			Namespace: "test-limits",
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": "test-app",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":             "test-app",
						"istio-injection": "disabled",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "nginx",
							Image: "nginx:latest",
							Resources: corev1.ResourceRequirements{
								Limits: corev1.ResourceList{
									"cpu":    resource.MustParse("100m"),
									"memory": resource.MustParse("128Mi"),
								},
							},
						},
					},
				},
			},
		},
	}

	// This should succeed
	if err := c.Create(ctx, deploymentWithLimits); err != nil {
		t.Errorf("Failed to create deployment with resource limits: %v", err)
	}
}

func TestIstioInjectionPolicy(t *testing.T) {
	c, _, cleanup := setupTestEnvironment(t)
	defer cleanup()

	ctx := context.Background()

	// Create namespace with forbidden label
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-istio",
			Labels: map[string]string{
				"istio-injection": "enabled",
				"test-policy":     "istio-injection",
			},
		},
	}

	// This should fail
	err := c.Create(ctx, ns)
	if err == nil {
		t.Error("Expected policy to deny namespace with istio-injection=enabled")
	}
}

func TestIstioRevisionLabelPolicy(t *testing.T) {
	c, _, cleanup := setupTestEnvironment(t)
	defer cleanup()

	ctx := context.Background()

	// Create namespace to trigger mutation
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-istio-rev",
			Labels: map[string]string{
				"test-policy":     "istio-revision",
				"istio-injection": "disabled",
			},
		},
	}

	if err := c.Create(ctx, ns); err != nil {
		t.Fatalf("Failed to create test namespace: %v", err)
	}

	// Wait for mutation
	time.Sleep(5 * time.Second)

	// Check if label was mutated
	mutatedNs := &corev1.Namespace{}
	if err := c.Get(ctx, client.ObjectKey{Name: "test-istio-rev"}, mutatedNs); err != nil {
		t.Fatalf("Failed to get mutated namespace: %v", err)
	}

	if mutatedNs.Labels["istio.io/rev"] != "asm-1-23" {
		t.Error("Expected istio.io/rev label to be set to asm-1-23")
	}
}

func TestPeerAuthenticationPolicy(t *testing.T) {
	c, _, cleanup := setupTestEnvironment(t)
	defer cleanup()

	ctx := context.Background()

	// Create test namespace
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-peer-auth",
			Labels: map[string]string{
				"test-policy": "peer-auth",
			},
		},
	}
	if err := c.Create(ctx, ns); err != nil {
		t.Fatalf("Failed to create test namespace: %v", err)
	}

	// Create PeerAuthentication with non-STRICT mode
	peerAuth := &securityv1beta1.PeerAuthentication{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-peer-auth",
			Namespace: "test-peer-auth",
		},
		Spec: securityv1beta1.PeerAuthenticationSpec{
			Mtls: &securityv1beta1.PeerAuthentication_MutualTLS{
				Mode: securityv1beta1.PeerAuthentication_MutualTLS_PERMISSIVE,
			},
		},
	}

	// This should fail
	err := c.Create(ctx, peerAuth)
	if err == nil {
		t.Error("Expected policy to deny PeerAuthentication with non-STRICT mode")
	}
}

// Add test for running all policies in production mode
func TestProductionPolicies(t *testing.T) {
	c, _, cleanup := setupTestEnvironment(t)
	defer cleanup()

	ctx := context.Background()

	// Create PolicyManager
	pm := NewPolicyManager(c)

	// Clean up any existing policies
	if err := pm.CleanupPolicies(ctx); err != nil {
		t.Fatalf("Failed to cleanup policies: %v", err)
	}

	// Apply production policies
	if err := pm.ApplyProductionPolicies(ctx); err != nil {
		t.Fatalf("Failed to apply production policies: %v", err)
	}

	// Verify all policies are ready
	time.Sleep(5 * time.Second)

	policies := []string{
		"mutate-ns-deployment-spotaffinity-prod",
		"require-resource-limits-prod",
		"validate-ns-istio-injection-prod",
		"mutate-cluster-namespace-istiolabel-prod",
	}

	for _, name := range policies {
		policy := &kyvernov1.ClusterPolicy{}
		if err := c.Get(ctx, client.ObjectKey{Name: name}, policy); err != nil {
			t.Errorf("Failed to get policy %s: %v", name, err)
			continue
		}

		if !policy.Status.Ready {
			t.Errorf("Policy %s is not ready", name)
		}
	}
}

// Helper functions
func int32Ptr(i int32) *int32 {
	return &i
}

func hasSpotToleration(deployment *appsv1.Deployment) bool {
	for _, toleration := range deployment.Spec.Template.Spec.Tolerations {
		if toleration.Key == "kubernetes.azure.com/scalesetpriority" &&
			toleration.Value == "spot" {
			return true
		}
	}
	return false
}

func hasPodAntiAffinity(deployment *appsv1.Deployment) bool {
	affinity := deployment.Spec.Template.Spec.Affinity
	if affinity == nil || affinity.PodAntiAffinity == nil {
		return false
	}
	return len(affinity.PodAntiAffinity.PreferredDuringSchedulingIgnoredDuringExecution) > 0
}

func hasNodeAffinity(deployment *appsv1.Deployment) bool {
	affinity := deployment.Spec.Template.Spec.Affinity
	if affinity == nil || affinity.NodeAffinity == nil {
		return false
	}
	return len(affinity.NodeAffinity.PreferredDuringSchedulingIgnoredDuringExecution) > 0
}
