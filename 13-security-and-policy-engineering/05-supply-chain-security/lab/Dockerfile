# pe-supply-demo — a DELIBERATELY non-distroless image for the Module 13.5 lab.
#
# Module 02.5 taught you to ship hardened, distroless, non-root images. This one does the
# OPPOSITE on purpose: a full Debian-slim userland plus a couple of pip packages. The fat
# base and real dependencies give Syft a meaty inventory and give Grype actual CVEs to
# find and triage. Do NOT use a base like this for a production workload.

FROM python:3.12-slim

# Install two real, widely-used packages so the SBOM and scan have substance. Nothing is
# copied in — the image only needs to be buildable and scannable, not to do real work.
RUN pip install --no-cache-dir requests flask

WORKDIR /app

# A trivial command keeps the image runnable without any application source.
CMD ["python", "-c", "print('pe-supply-demo: built to be inventoried and scanned')"]
