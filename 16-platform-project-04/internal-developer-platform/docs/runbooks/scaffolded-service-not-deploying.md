# Runbook — A scaffolded service didn't deploy

> **When to use:** a developer created a service from a golden path, but it isn't
> running (not in the cluster, or ArgoCD never created an Application for it).

## Triage — find where the chain broke

The scaffold → repo → CI → GitOps → ArgoCD → running chain has a few failure points.
Check them in order:

1. **Did scaffolding succeed?** In Backstage, open the scaffolder task log for the
   run. A failed `fetch:template`, `publish:github`, or `catalog:register` step stops
   everything downstream. Fix the template input or GitHub permissions and re-run.

2. **Did the repo get the skeleton?** Confirm the new repo has `gitops/`, the CI
   workflow, `Dockerfile`, and `catalog-info.yaml`. A partial skeleton points at a
   template bug.

3. **Did CI build and push an image?** Check the repo's Actions. A failed Trivy gate
   (critical CVE) or push is a *good* stop — fix the vulnerability; don't bypass the
   gate. No image means nothing to deploy.

4. **Did the GitOps overlay reach the config repo?** The service's overlay must exist
   at `apps/<team>/<service>/overlays/dev/` in the Project 2 config repo. In Pass 1 this
   is a manual copy; in Pass 2 it's an automated PR — check the PR was opened and merged.

5. **Did ArgoCD generate an Application?** Project 2's ApplicationSet watches
   `apps/*/*/overlays/*`. If the folder is there but no Application appeared:

   ```bash
   kubectl -n argocd get applicationset
   kubectl -n argocd get applications | grep <service>
   ```

   If missing, the overlay path/shape probably doesn't match the generator's pattern —
   compare it to a working service. See Project 2's
   [out-of-sync runbook](../../../../09-platform-project-02/gitops-platform/docs/runbooks/argocd-app-out-of-sync.md).

6. **Is it failing admission?** The namespace enforces the `restricted` Pod Security
   Standard and Kyverno policies (signed images, labels). A non-compliant workload is
   rejected. The skeleton ships compliant by default, so this usually means a hand-edit
   regressed it — re-align with the golden-path defaults.

## Resolve

Fix the broken link, then let the chain continue — don't hand-deploy with `kubectl`
(that breaks the GitOps source of truth). The whole point is that the service reaches
production through the platform, reproducibly.

## Prevent

- Keep the golden-path template and skeleton tested (render + `kubectl kustomize` the
  overlay in CI) so scaffolding can't emit broken config.
- Version templates; when you fix a defect, bump the version and help teams migrate
  (ADR-018).

## Escalation

If scaffolding itself is broken for everyone (a bad template version, Backstage down),
treat it as a platform incident — the IDP is now critical infrastructure with its own
SLOs and on-call ([Phase 13 · Platform SRE](../../../../17-platform-sre/)).
