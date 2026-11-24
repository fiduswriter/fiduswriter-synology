# Derived image: the official Fidus Writer image plus the synology Django
# app (SSO middleware for the synology-docker-bridge identity headers).
# Built by the SPK generator via appBuild (packaging/app.json) with
# SPK_PLATFORM set to the target platform, e.g. linux/arm64.

ARG BASE_IMAGE=fiduswriter/fiduswriter:5.0.0a3
FROM ${BASE_IMAGE}

USER root

COPY . /tmp/fiduswriter-synology
RUN venv/bin/pip install /tmp/fiduswriter-synology \
    && rm -rf /tmp/fiduswriter-synology

USER fiduswriter
