import os

from fastapi import FastAPI

# SERVICE_NAME is rendered by the Backstage scaffolder from the developer's input.
# It is a plain string, so this file stays valid Python in the template.
SERVICE_NAME = "${{ values.name }}"

app = FastAPI(title=SERVICE_NAME)


@app.get("/")
def root() -> dict:
    return {"message": f"hello from {SERVICE_NAME}", "uid": os.getuid()}


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}
