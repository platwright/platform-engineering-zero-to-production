#!/usr/bin/env python3
"""A tiny mutating admission webhook (standard library only).

It injects platform.example.com/team and platform.example.com/cost-center LABELS
onto Pods, reading the values from the Pod's namespace ANNOTATIONS. Developers never
set these by hand; the platform stamps them so FinOps cost reports are accurate.

Runs on a stock python:3.12-slim image via a ConfigMap — no build step.
"""
import base64
import json
import os
import ssl
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

API = "https://kubernetes.default.svc"
TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"  # noqa: S105
CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
INJECT_KEYS = [
    "platform.example.com/team",
    "platform.example.com/cost-center",
]


def namespace_annotations(namespace):
    """Read the namespace's annotations via the in-cluster API. Fail soft."""
    try:
        with open(TOKEN_PATH, encoding="utf-8") as handle:
            token = handle.read().strip()
        ctx = ssl.create_default_context(cafile=CA_PATH)
        req = urllib.request.Request(
            "{}/api/v1/namespaces/{}".format(API, namespace),
            headers={"Authorization": "Bearer {}".format(token)},
        )
        with urllib.request.urlopen(req, context=ctx, timeout=3) as resp:
            meta = json.load(resp).get("metadata", {})
            return meta.get("annotations", {}) or {}
    except Exception as exc:  # fail soft: inject nothing rather than block the Pod
        print("could not read namespace {}: {}".format(namespace, exc), flush=True)
        return {}


def escape(path_segment):
    """Escape a JSON Pointer path segment (RFC 6901): ~ -> ~0, / -> ~1."""
    return path_segment.replace("~", "~0").replace("/", "~1")


def build_patch(pod, annotations):
    """Return a JSON Patch that adds any missing injected labels."""
    metadata = pod.get("metadata", {}) or {}
    labels = metadata.get("labels", {}) or {}
    patch = []
    if "labels" not in metadata:
        patch.append({"op": "add", "path": "/metadata/labels", "value": {}})
    for key in INJECT_KEYS:
        value = annotations.get(key)
        if value and key not in labels:
            patch.append({
                "op": "add",
                "path": "/metadata/labels/" + escape(key),
                "value": value,
            })
    return patch


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802 (name mandated by BaseHTTPRequestHandler)
        length = int(self.headers.get("Content-Length", 0))
        review = json.loads(self.rfile.read(length) or b"{}")
        req = review.get("request", {}) or {}
        pod = req.get("object", {}) or {}
        annotations = namespace_annotations(req.get("namespace", ""))
        patch = build_patch(pod, annotations)

        response = {"uid": req.get("uid", ""), "allowed": True}
        if patch:
            response["patchType"] = "JSONPatch"
            response["patch"] = base64.b64encode(
                json.dumps(patch).encode("utf-8")
            ).decode("utf-8")

        out = json.dumps({
            "apiVersion": "admission.k8s.io/v1",
            "kind": "AdmissionReview",
            "response": response,
        }).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def log_message(self, *args):
        pass  # keep the logs quiet


def main():
    port = int(os.environ.get("PORT", "8443"))
    httpd = HTTPServer(("0.0.0.0", port), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile="/tls/tls.crt", keyfile="/tls/tls.key")
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    print("serving mutating webhook on :{}".format(port), flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
