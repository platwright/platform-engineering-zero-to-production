package controller

import (
	"context"
	"fmt"

	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	platformv1alpha1 "example.com/namespace-provisioner/api/v1alpha1"
)

const finalizerName = "platform.example.com/finalizer"

// EnvironmentReconciler reconciles an Environment into a namespace, ResourceQuota,
// LimitRange, and RBAC — the Project 1 onboarding runbook, encoded as software.
type EnvironmentReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=platform.example.com,resources=environments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=platform.example.com,resources=environments/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=platform.example.com,resources=environments/finalizers,verbs=update
// +kubebuilder:rbac:groups="",resources=namespaces,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=resourcequotas;limitranges,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=rbac.authorization.k8s.io,resources=rolebindings,verbs=get;list;watch;create;update;patch;delete

// Reconcile drives the actual cluster state toward the Environment's spec. It is
// level-triggered and idempotent: it may run many times and must converge each time.
func (r *EnvironmentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	l := log.FromContext(ctx)

	env := &platformv1alpha1.Environment{}
	if err := r.Get(ctx, req.NamespacedName, env); err != nil {
		// NotFound: the object was deleted and GC/finalizers already ran. Nothing to do.
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Handle deletion: run finalizer cleanup, then let deletion proceed.
	if !env.DeletionTimestamp.IsZero() {
		if controllerutil.ContainsFinalizer(env, finalizerName) {
			if err := r.finalize(ctx, env); err != nil {
				return ctrl.Result{}, err
			}
			controllerutil.RemoveFinalizer(env, finalizerName)
			if err := r.Update(ctx, env); err != nil {
				return ctrl.Result{}, err
			}
		}
		return ctrl.Result{}, nil
	}

	// Ensure our finalizer is present before we create anything to clean up.
	if !controllerutil.ContainsFinalizer(env, finalizerName) {
		controllerutil.AddFinalizer(env, finalizerName)
		if err := r.Update(ctx, env); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Provision the child resources. Any failure marks the Environment Degraded.
	if err := r.ensureNamespace(ctx, env); err != nil {
		return r.markDegraded(ctx, env, "NamespaceError", err)
	}
	if err := r.ensureResourceQuota(ctx, env); err != nil {
		return r.markDegraded(ctx, env, "QuotaError", err)
	}
	if err := r.ensureLimitRange(ctx, env); err != nil {
		return r.markDegraded(ctx, env, "LimitRangeError", err)
	}
	if err := r.ensureRBAC(ctx, env); err != nil {
		return r.markDegraded(ctx, env, "RBACError", err)
	}

	l.Info("environment reconciled", "namespace", namespaceName(env), "tier", env.Spec.Tier)
	return r.markReady(ctx, env)
}

// namespaceName derives the managed namespace from team and tier (e.g. payments-dev).
func namespaceName(env *platformv1alpha1.Environment) string {
	return fmt.Sprintf("%s-%s", env.Spec.Team, env.Spec.Tier)
}

// ensureNamespace creates or updates the namespace, stamping platform labels and the
// annotations the cost-label webhook (Module 10.3) reads.
func (r *EnvironmentReconciler) ensureNamespace(ctx context.Context, env *platformv1alpha1.Environment) error {
	ns := &corev1.Namespace{}
	ns.Name = namespaceName(env)
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, ns, func() error {
		if ns.Labels == nil {
			ns.Labels = map[string]string{}
		}
		ns.Labels["platform.example.com/team"] = env.Spec.Team
		ns.Labels["platform.example.com/tier"] = env.Spec.Tier
		ns.Labels["platform.example.com/managed-by"] = "namespace-provisioner"
		if ns.Annotations == nil {
			ns.Annotations = map[string]string{}
		}
		ns.Annotations["platform.example.com/team"] = env.Spec.Team
		if env.Spec.CostCenter != "" {
			ns.Annotations["platform.example.com/cost-center"] = env.Spec.CostCenter
		}
		// The namespace is cluster-scoped and cleaned up by our finalizer, so we do
		// not set an owner reference on it here.
		return nil
	})
	return err
}

// ensureResourceQuota caps total resource usage in the namespace, scaled by tier.
func (r *EnvironmentReconciler) ensureResourceQuota(ctx context.Context, env *platformv1alpha1.Environment) error {
	quota := &corev1.ResourceQuota{}
	quota.Name = "platform-quota"
	quota.Namespace = namespaceName(env)
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, quota, func() error {
		quota.Spec.Hard = quotaForTier(env.Spec.Tier)
		return controllerutil.SetControllerReference(env, quota, r.Scheme)
	})
	return err
}

// ensureLimitRange sets default container requests/limits so Pods inherit sane values.
func (r *EnvironmentReconciler) ensureLimitRange(ctx context.Context, env *platformv1alpha1.Environment) error {
	lr := &corev1.LimitRange{}
	lr.Name = "platform-limits"
	lr.Namespace = namespaceName(env)
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, lr, func() error {
		lr.Spec.Limits = []corev1.LimitRangeItem{{
			Type: corev1.LimitTypeContainer,
			Default: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("500m"),
				corev1.ResourceMemory: resource.MustParse("512Mi"),
			},
			DefaultRequest: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("100m"),
				corev1.ResourceMemory: resource.MustParse("128Mi"),
			},
		}}
		return controllerutil.SetControllerReference(env, lr, r.Scheme)
	})
	return err
}

// ensureRBAC binds the team's group to the built-in "edit" ClusterRole in the namespace.
func (r *EnvironmentReconciler) ensureRBAC(ctx context.Context, env *platformv1alpha1.Environment) error {
	rb := &rbacv1.RoleBinding{}
	rb.Name = "team-edit"
	rb.Namespace = namespaceName(env)
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, rb, func() error {
		rb.RoleRef = rbacv1.RoleRef{
			APIGroup: rbacv1.GroupName,
			Kind:     "ClusterRole",
			Name:     "edit",
		}
		rb.Subjects = []rbacv1.Subject{{
			APIGroup: rbacv1.GroupName,
			Kind:     "Group",
			Name:     "team-" + env.Spec.Team,
		}}
		return controllerutil.SetControllerReference(env, rb, r.Scheme)
	})
	return err
}

// finalize deletes the managed namespace (cascading to its contents) before the
// Environment is allowed to disappear.
func (r *EnvironmentReconciler) finalize(ctx context.Context, env *platformv1alpha1.Environment) error {
	ns := &corev1.Namespace{}
	ns.Name = namespaceName(env)
	if err := r.Delete(ctx, ns); err != nil {
		return client.IgnoreNotFound(err)
	}
	return nil
}

// quotaForTier returns per-tier hard limits: dev is small, prod is generous.
func quotaForTier(tier string) corev1.ResourceList {
	switch tier {
	case "prod":
		return corev1.ResourceList{
			corev1.ResourceRequestsCPU:    resource.MustParse("8"),
			corev1.ResourceRequestsMemory: resource.MustParse("16Gi"),
			corev1.ResourceLimitsCPU:      resource.MustParse("16"),
			corev1.ResourceLimitsMemory:   resource.MustParse("32Gi"),
			corev1.ResourcePods:           resource.MustParse("50"),
		}
	case "staging":
		return corev1.ResourceList{
			corev1.ResourceRequestsCPU:    resource.MustParse("4"),
			corev1.ResourceRequestsMemory: resource.MustParse("8Gi"),
			corev1.ResourceLimitsCPU:      resource.MustParse("8"),
			corev1.ResourceLimitsMemory:   resource.MustParse("16Gi"),
			corev1.ResourcePods:           resource.MustParse("25"),
		}
	default: // dev
		return corev1.ResourceList{
			corev1.ResourceRequestsCPU:    resource.MustParse("1"),
			corev1.ResourceRequestsMemory: resource.MustParse("2Gi"),
			corev1.ResourceLimitsCPU:      resource.MustParse("2"),
			corev1.ResourceLimitsMemory:   resource.MustParse("4Gi"),
			corev1.ResourcePods:           resource.MustParse("10"),
		}
	}
}

// markReady records success in status and stops proactive requeue.
func (r *EnvironmentReconciler) markReady(ctx context.Context, env *platformv1alpha1.Environment) (ctrl.Result, error) {
	env.Status.Phase = "Ready"
	env.Status.Namespace = namespaceName(env)
	env.Status.ObservedGeneration = env.Generation
	meta.SetStatusCondition(&env.Status.Conditions, metav1.Condition{
		Type:               "Ready",
		Status:             metav1.ConditionTrue,
		Reason:             "Provisioned",
		Message:            "namespace, quota, limits, and RBAC are in place",
		ObservedGeneration: env.Generation,
	})
	return ctrl.Result{}, r.Status().Update(ctx, env)
}

// markDegraded records a failure in status and returns the error so the queue retries.
func (r *EnvironmentReconciler) markDegraded(ctx context.Context, env *platformv1alpha1.Environment, reason string, cause error) (ctrl.Result, error) {
	env.Status.Phase = "Degraded"
	env.Status.ObservedGeneration = env.Generation
	meta.SetStatusCondition(&env.Status.Conditions, metav1.Condition{
		Type:               "Ready",
		Status:             metav1.ConditionFalse,
		Reason:             reason,
		Message:            cause.Error(),
		ObservedGeneration: env.Generation,
	})
	// Best-effort status write; return the original cause for backoff-and-retry.
	_ = r.Status().Update(ctx, env)
	return ctrl.Result{}, cause
}

// SetupWithManager wires the controller to watch Environments and the children it owns,
// so deleting a quota or RoleBinding triggers a reconcile that restores it.
func (r *EnvironmentReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.Environment{}).
		Owns(&corev1.ResourceQuota{}).
		Owns(&corev1.LimitRange{}).
		Owns(&rbacv1.RoleBinding{}).
		Complete(r)
}
