// Package tests provides integration tests for Kyverno policies
package tests

import (
	"context"
	"testing"
	"time"

	kyvernov1 "github.com/kyverno/kyverno/api/kyverno/v1"
	policyreportv1alpha2 "github.com/kyverno/kyverno/api/policyreport/v1alpha2"
	istiotypes "istio.io/api/security/v1beta1"
	istiosecurityv1beta1 "istio.io/client-go/pkg/apis/security/v1beta1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/kubernetes"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

const (
	// testTimeout is the duration to wait for policy evaluations and mutations
	testTimeout = 3 * time.Second
	// testNamespace is the namespace where test resources will be created
	testNamespace = "kyverno-test"
)

// TestSuite represents a collection of test cases for Kyverno policies.
// It provides shared functionality for interacting with the Kubernetes cluster
// and managing test resources.
type TestSuite struct {
	client    client.Client         // Controller-runtime client for high-level operations
	clientset *kubernetes.Clientset // Standard Kubernetes client for low-level operations
	cleanup   func()                // Function to clean up test resources
}

// setupTestSuite initializes the test environment by:
// - Creating a Kubernetes client
// - Setting up necessary API schemes (Kyverno, Istio)
// - Creating a test namespace
// - Providing cleanup functionality
func setupTestSuite(t *testing.T) *TestSuite {
	// Try local kubeconfig first, then fall back to default location
	localKubeconfig := "kubeconfig"
	var config *rest.Config
	var err error

	// Try local kubeconfig first
	config, err = clientcmd.BuildConfigFromFlags("", localKubeconfig)
	if err != nil {
		t.Logf("Local kubeconfig not found, trying default location: %v", err)
		// Fall back to default kubeconfig location
		config, err = clientcmd.BuildConfigFromFlags("", clientcmd.RecommendedHomeFile)
		if err != nil {
			t.Fatalf("Error building kubeconfig: %v", err)
		}
	}

	// Create clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		t.Fatalf("Error creating kubernetes client: %v", err)
	}

	// Create scheme with required types
	scheme := runtime.NewScheme()
	_ = clientgoscheme.AddToScheme(scheme)
	_ = istiosecurityv1beta1.AddToScheme(scheme)
	_ = policyreportv1alpha2.AddToScheme(scheme)
	_ = kyvernov1.AddToScheme(scheme)

	// Create controller-runtime client
	c, err := client.New(config, client.Options{
		Scheme: scheme,
	})
	if err != nil {
		t.Fatalf("Error creating controller-runtime client: %v", err)
	}

	// Delete existing namespace if it exists
	existingNs := &corev1.Namespace{}
	err = c.Get(context.Background(), client.ObjectKey{Name: testNamespace}, existingNs)
	if err == nil {
		t.Logf("🗑️  Cleaning up existing namespace %s...", testNamespace)
		// Delete with foreground propagation
		propagation := metav1.DeletePropagationForeground
		deleteOptions := client.DeleteOptions{
			PropagationPolicy: &propagation,
		}
		if err := c.Delete(context.Background(), existingNs, &deleteOptions); err != nil {
			t.Logf("⚠️  Warning: Failed to delete existing namespace: %v", err)
		}

		// Wait for namespace deletion with longer timeout
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		// Poll every second for namespace deletion
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				t.Fatalf("⏰ Timed out waiting for namespace %s to be deleted. You may need to delete it manually.", testNamespace)
			case <-ticker.C:
				err := c.Get(context.Background(), client.ObjectKey{Name: testNamespace}, existingNs)
				if err != nil {
					t.Logf("✨ Successfully deleted namespace %s", testNamespace)
					goto createNamespace
				}
				t.Logf("⏳ Waiting for namespace %s to be deleted...", testNamespace)
			}
		}
	}

createNamespace:
	t.Logf("🔨 Creating test namespace %s...", testNamespace)
	// Create test namespace
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: testNamespace,
			Labels: map[string]string{
				"worker-type": "spot",
			},
		},
	}
	if err := c.Create(context.Background(), ns); err != nil {
		t.Fatalf("💥 Failed to create test namespace: %v", err)
	}
	t.Log("✅ Test namespace created successfully")

	return &TestSuite{
		client:    c,
		clientset: clientset,
		cleanup: func() {
			ctx := context.Background()
			t.Log("🧹 Running cleanup...")
			propagation := metav1.DeletePropagationForeground
			deleteOptions := client.DeleteOptions{
				PropagationPolicy: &propagation,
			}
			if err := c.Delete(ctx, ns, &deleteOptions); err != nil {
				t.Logf("⚠️  Error cleaning up namespace %s: %v", testNamespace, err)
			} else {
				t.Log("✨ Cleanup completed successfully")
			}
		},
	}
}

// TestKyvernoPolicies is the main test function that runs all policy tests.
// Each policy test is run as a subtest to provide clear test organization and
// independent test execution.
func TestKyvernoPolicies(t *testing.T) {
	suite := setupTestSuite(t)
	defer suite.cleanup()

	// Run each policy test as a subtest
	t.Run("SpotAffinity", suite.testSpotAffinityPolicy)
	t.Run("ResourceLimits", suite.testResourceLimitsPolicy)
	t.Run("IstioInjection", suite.testIstioInjectionPolicy)
	t.Run("IstioRevisionLabel", suite.testIstioRevisionLabelPolicy)
	t.Run("PeerAuthentication", suite.testPeerAuthenticationPolicy)
}

// testSpotAffinityPolicy verifies that the spot instance configuration policy:
// - Adds correct node affinity for spot instances
// - Configures appropriate pod anti-affinity
// - Sets required spot instance tolerations
func (s *TestSuite) testSpotAffinityPolicy(t *testing.T) {
	t.Log("🚀 Testing Spot Affinity Policy...")
	ctx := context.Background()

	t.Log("📦 Creating test deployment in spot namespace...")
	deployment := s.createTestDeployment(t, "spot-test", map[string]string{
		"worker-type": "spot",
	})

	t.Log("⏳ Waiting for mutation...")
	time.Sleep(testTimeout)

	t.Log("🔍 Verifying deployment mutation...")
	mutated := &appsv1.Deployment{}
	if err := s.client.Get(ctx, client.ObjectKey{
		Namespace: testNamespace,
		Name:      deployment.Name,
	}, mutated); err != nil {
		t.Fatalf("💥 Failed to get mutated deployment: %v", err)
	}

	verifySpotConfiguration(t, mutated)
}

// testResourceLimitsPolicy verifies that the resource limits policy:
// - Audits deployments without resource limits
// - Allows deployments with proper resource limits
// - Generates appropriate policy reports for violations
func (s *TestSuite) testResourceLimitsPolicy(t *testing.T) {
	t.Log("🚀 Testing Resource Limits Policy...")
	ctx := context.Background()

	// Verify policy exists
	policy := &kyvernov1.ClusterPolicy{}
	err := s.client.Get(ctx, client.ObjectKey{Name: "require-resource-limits"}, policy)
	if err != nil {
		t.Skip("⏭️  Skipping ResourceLimits test: Policy not installed")
		return
	}

	// Test case 1: Deployment without limits should be audited
	deploymentNoLimits := s.createDeploymentSpec("no-limits-test", nil)
	err = s.client.Create(ctx, deploymentNoLimits)
	if err != nil {
		t.Errorf("💥 Unexpected error creating deployment without limits: %v", err)
		return
	}
	defer s.client.Delete(ctx, deploymentNoLimits)

	// Wait for audit
	time.Sleep(testTimeout)

	// Check for audit entry
	reports := &policyreportv1alpha2.PolicyReportList{}
	if err := s.client.List(ctx, reports); err != nil {
		t.Errorf("💥 Failed to list policy reports: %v", err)
		return
	}

	// Track unique policy violations
	uniqueViolations := make(map[string]bool)
	for _, report := range reports.Items {
		for _, result := range report.Results {
			if result.Policy == "require-resource-limits" {
				// Create a unique key based on policy and resource name (if available)
				key := result.Policy
				if len(result.Resources) > 0 {
					key += ":" + result.Resources[0].Name
				}
				if !uniqueViolations[key] {
					uniqueViolations[key] = true
					t.Log("✅ Found audit entry for deployment without resource limits")
				}
			}
		}
	}

	if len(uniqueViolations) == 0 {
		t.Error("❌ No audit entry found for deployment without resource limits")
	}

	// Test case 2: Deployment with limits should be accepted
	deploymentWithLimits := s.createDeploymentSpec("with-limits-test", &corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("128Mi"),
		},
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("64Mi"),
		},
	})

	if err := s.client.Create(ctx, deploymentWithLimits); err != nil {
		t.Errorf("💥 Failed to create deployment with resource limits: %v", err)
	} else {
		t.Log("✅ Policy correctly accepted deployment with resource limits")
		// Clean up
		_ = s.client.Delete(ctx, deploymentWithLimits)
	}
}

// checkIstioInstalled verifies if Istio is installed in the cluster
// by checking for the istiod service. Returns false if Istio is not
// installed, allowing tests to be skipped appropriately.
func (s *TestSuite) checkIstioInstalled(t *testing.T) bool {
	_, err := s.clientset.CoreV1().Services("istio-system").Get(context.Background(), "istiod", metav1.GetOptions{})
	if err != nil {
		t.Log("⏭️  Skipping Istio test: Istio not installed (this is expected in non-prod environments)")
		return false
	}
	t.Log("✨ Istio installation detected")
	return true
}

// testIstioInjectionPolicy verifies that the Istio injection policy:
// - Prevents manual enablement of Istio injection via labels
// - Applies to both namespaces and deployments
// Note: Test is skipped if Istio is not installed
func (s *TestSuite) testIstioInjectionPolicy(t *testing.T) {
	if !s.checkIstioInstalled(t) {
		t.Skip()
		return
	}

	ctx := context.Background()

	// Verify policy exists
	policy := &kyvernov1.ClusterPolicy{}
	err := s.client.Get(ctx, client.ObjectKey{Name: "restrict-istio-injection"}, policy)
	if err != nil {
		t.Skip("ℹ️  Skipping IstioInjection test: Policy not installed")
		return
	}

	// Test case 1: Namespace with istio-injection=enabled should be rejected
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-istio-injection",
			Labels: map[string]string{
				"istio-injection": "enabled",
			},
		},
	}

	err = s.client.Create(ctx, ns)
	if err == nil {
		t.Error("❌ Expected policy to reject namespace with istio-injection=enabled")
		// Clean up namespace if it was created
		_ = s.client.Delete(ctx, ns)
	} else {
		t.Log("✅ Policy correctly rejected namespace with istio-injection=enabled")
	}

	// Test case 2: Deployment with istio-injection=enabled should be rejected
	deployment := s.createDeploymentSpec("test-istio-injection", nil)
	deployment.ObjectMeta.Labels = map[string]string{
		"istio-injection": "enabled",
	}

	err = s.client.Create(ctx, deployment)
	if err == nil {
		t.Error("❌ Expected policy to reject deployment with istio-injection=enabled")
		// Clean up deployment if it was created
		_ = s.client.Delete(ctx, deployment)
	} else {
		t.Log("✅ Policy correctly rejected deployment with istio-injection=enabled")
	}
}

// testIstioRevisionLabelPolicy verifies that the Istio revision label policy:
// - Mutates empty istio.io/rev labels to the correct version
// - Maintains existing valid revision labels
// Note: Test is skipped if Istio is not installed
func (s *TestSuite) testIstioRevisionLabelPolicy(t *testing.T) {
	if !s.checkIstioInstalled(t) {
		t.Skip()
		return
	}

	ctx := context.Background()

	// Clean up any existing namespace first
	existingNs := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-istio-rev",
		},
	}
	_ = s.client.Delete(ctx, existingNs)

	// Wait for deletion with timeout
	waitCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	for {
		err := s.client.Get(ctx, client.ObjectKey{Name: "test-istio-rev"}, existingNs)
		if err != nil {
			break // Namespace is gone
		}

		select {
		case <-waitCtx.Done():
			t.Skip("ℹ️  Skipping test: Could not clean up previous namespace")
			return
		case <-time.After(500 * time.Millisecond):
			continue
		}
	}

	// Create namespace with empty istio.io/rev label
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: "test-istio-rev",
			Labels: map[string]string{
				"istio.io/rev": "",
			},
		},
	}
	if err := s.client.Create(ctx, ns); err != nil {
		t.Fatalf("Failed to create test namespace: %v", err)
	}
	defer s.client.Delete(ctx, ns) // Clean up after test

	// Wait for mutation
	time.Sleep(testTimeout)

	// Verify label was mutated
	mutated := &corev1.Namespace{}
	if err := s.client.Get(ctx, client.ObjectKey{Name: ns.Name}, mutated); err != nil {
		t.Fatalf("Failed to get mutated namespace: %v", err)
	}

	if rev := mutated.Labels["istio.io/rev"]; rev != "asm-1-23" {
		t.Errorf("❌ Expected istio.io/rev=asm-1-23, got %s", rev)
	} else {
		t.Log("✅ Istio revision label correctly mutated")
	}
}

// testPeerAuthenticationPolicy verifies that the PeerAuthentication policy:
// - Audits non-strict mTLS configurations
// - Generates appropriate policy reports for violations
// Note: Test is skipped if Istio is not installed
func (s *TestSuite) testPeerAuthenticationPolicy(t *testing.T) {
	if !s.checkIstioInstalled(t) {
		t.Skip()
		return
	}

	ctx := context.Background()

	// Verify policy exists
	policy := &kyvernov1.ClusterPolicy{}
	err := s.client.Get(ctx, client.ObjectKey{Name: "audit-cluster-peerauthentication-mtls"}, policy)
	if err != nil {
		t.Skip("ℹ️  Skipping PeerAuthentication test: Policy not installed")
		return
	}

	// Create PeerAuthentication with PERMISSIVE mode
	pa := &istiosecurityv1beta1.PeerAuthentication{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-mtls",
			Namespace: testNamespace,
		},
		Spec: istiotypes.PeerAuthentication{
			Mtls: &istiotypes.PeerAuthentication_MutualTLS{
				Mode: istiotypes.PeerAuthentication_MutualTLS_PERMISSIVE,
			},
		},
	}

	// This should be audited but not blocked
	if err := s.client.Create(ctx, pa); err != nil {
		t.Fatalf("❌ Failed to create PeerAuthentication: %v", err)
	}
	defer s.client.Delete(ctx, pa) // Clean up after test

	// Wait for audit
	time.Sleep(testTimeout)

	// Verify audit entry exists
	reports := &policyreportv1alpha2.PolicyReportList{}
	if err := s.client.List(ctx, reports); err != nil {
		t.Fatalf("❌ Failed to list policy reports: %v", err)
	}

	found := false
	for _, report := range reports.Items {
		for _, result := range report.Results {
			if result.Policy == "audit-cluster-peerauthentication-mtls" {
				found = true
				t.Log("✅ Found audit entry for non-strict mTLS PeerAuthentication")
				break
			}
		}
	}

	if !found {
		t.Error("❌ No audit entry found for non-strict mTLS PeerAuthentication")
	}
}

// Helper functions

// createTestDeployment creates a test deployment with the given name and labels
// in the test namespace. It fails the test if deployment creation fails.
func (s *TestSuite) createTestDeployment(t *testing.T, name string, labels map[string]string) *appsv1.Deployment {
	deployment := s.createDeploymentSpec(name, nil)
	deployment.ObjectMeta.Labels = labels

	if err := s.client.Create(context.Background(), deployment); err != nil {
		t.Fatalf("Failed to create test deployment: %v", err)
	}

	return deployment
}

// createDeploymentSpec creates a deployment specification with the given name
// and resource requirements. If resources is nil, empty resource requirements
// are used.
func (s *TestSuite) createDeploymentSpec(name string, resources *corev1.ResourceRequirements) *appsv1.Deployment {
	if resources == nil {
		resources = &corev1.ResourceRequirements{} // Initialize empty resource requirements if nil
	}
	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: testNamespace,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": name,
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app": name,
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:      "nginx",
							Image:     "nginx:latest",
							Resources: *resources,
						},
					},
				},
			},
		},
	}
	return deployment
}

// verifySpotConfiguration checks if a deployment has all required spot instance
// configurations:
// - Spot instance toleration
// - Pod anti-affinity for high availability
// - Node affinity for spot instance scheduling
func verifySpotConfiguration(t *testing.T, deployment *appsv1.Deployment) {
	t.Log("🔍 Verifying spot configuration...")

	if !hasSpotToleration(deployment) {
		t.Error("❌ Spot toleration not found")
		return
	}
	t.Log("✅ Spot toleration verified")

	if !hasPodAntiAffinity(deployment) {
		t.Error("❌ Pod anti-affinity not found")
		return
	}
	t.Log("✅ Pod anti-affinity verified")

	if !hasNodeAffinity(deployment) {
		t.Error("❌ Node affinity for spot instances not found")
		return
	}
	t.Log("✅ Node affinity verified")

	t.Log("🎉 All spot configurations verified successfully")
}

// hasSpotToleration checks if a deployment has the required toleration
// for spot instances
func hasSpotToleration(deployment *appsv1.Deployment) bool {
	for _, toleration := range deployment.Spec.Template.Spec.Tolerations {
		if toleration.Key == "kubernetes.azure.com/scalesetpriority" {
			return true
		}
	}
	return false
}

// hasPodAntiAffinity checks if a deployment has pod anti-affinity configured
func hasPodAntiAffinity(deployment *appsv1.Deployment) bool {
	if deployment.Spec.Template.Spec.Affinity == nil ||
		deployment.Spec.Template.Spec.Affinity.PodAntiAffinity == nil {
		return false
	}
	return true
}

// hasNodeAffinity checks if a deployment has node affinity configured
// for spot instances
func hasNodeAffinity(deployment *appsv1.Deployment) bool {
	if deployment.Spec.Template.Spec.Affinity == nil ||
		deployment.Spec.Template.Spec.Affinity.NodeAffinity == nil {
		return false
	}
	return true
}

func int32Ptr(i int32) *int32 {
	return &i
}
