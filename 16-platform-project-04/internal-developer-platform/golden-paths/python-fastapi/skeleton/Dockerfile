# Hardened Python build: install deps, then run as a NON-ROOT user on a slim base.
# (The course prefers distroless where practical; python-slim + a non-root user keeps
# the FastAPI/uvicorn runtime simple while staying non-root and minimal.)
FROM python:3.12-slim

# Create a non-root user to run as.
RUN useradd --create-home --uid 65532 appuser
WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

USER appuser
EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
