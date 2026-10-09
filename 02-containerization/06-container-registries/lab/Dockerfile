# A trivial, versioned image. Change "v1" to "v2" during the lab to prove that a
# TAG can be moved to different bytes, while a DIGEST always refers to the same ones.
FROM alpine:3.20
RUN echo "v1" > /version
CMD ["cat", "/version"]
