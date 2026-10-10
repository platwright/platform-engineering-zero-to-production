package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EnvironmentSpec is the desired state of an Environment. It mirrors the OpenAPI
// schema and CEL rules in config/crd so the Go type and the CRD stay in step.
type EnvironmentSpec struct {
	// Team owns the environment; it becomes the namespace name prefix.
	// +kubebuilder:validation:Pattern=`^[a-z][a-z0-9-]{1,30}$`
	Team string `json:"team"`

	// Tier is one of dev, staging, or prod.
	// +kubebuilder:validation:Enum=dev;staging;prod
	Tier string `json:"tier"`

	// Owner is the accountable owner email (required for prod).
	// +optional
	Owner string `json:"owner,omitempty"`

	// Replicas is the default workload replica count for the environment.
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=20
	// +kubebuilder:default=1
	// +optional
	Replicas int32 `json:"replicas,omitempty"`

	// CostCenter is the FinOps cost center (cc-NNNN) propagated to the namespace.
	// +optional
	CostCenter string `json:"costCenter,omitempty"`
}

// EnvironmentStatus is the observed state of an Environment, written by the controller.
type EnvironmentStatus struct {
	// Phase is a coarse summary: Pending, Ready, or Degraded.
	// +optional
	Phase string `json:"phase,omitempty"`

	// Namespace is the namespace this Environment provisioned.
	// +optional
	Namespace string `json:"namespace,omitempty"`

	// ObservedGeneration is the .metadata.generation last reconciled.
	// +optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// Conditions follow the standard Kubernetes condition conventions.
	// +optional
	// +listType=map
	// +listMapKey=type
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Cluster,shortName=env
// +kubebuilder:printcolumn:name="Team",type=string,JSONPath=`.spec.team`
// +kubebuilder:printcolumn:name="Tier",type=string,JSONPath=`.spec.tier`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// Environment is the Schema for the environments API.
type Environment struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   EnvironmentSpec   `json:"spec,omitempty"`
	Status EnvironmentStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// EnvironmentList contains a list of Environment.
type EnvironmentList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Environment `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Environment{}, &EnvironmentList{})
}
