# Debian with the newest Proxmox VE packages of one repository component.
# The drift workflow rebuilds this image when the Proxmox package index changes.
FROM debian:trixie

ARG PVE_COMPONENT=pve-no-subscription
ARG PVE_KEYRING=/usr/share/keyrings/proxmox-archive-keyring.gpg
ARG PVE_KEYRING_URL=https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl \
    && curl --fail --silent --show-error --location --output "${PVE_KEYRING}" "${PVE_KEYRING_URL}" \
    && echo "deb [signed-by=${PVE_KEYRING}] http://download.proxmox.com/debian/pve trixie ${PVE_COMPONENT}" \
        > /etc/apt/sources.list.d/pve.list

# Package maintainer scripts must not start services during the image build.
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod 0755 /usr/sbin/policy-rc.d \
    && apt-get update \
    && apt-get install --yes --no-install-recommends pve-manager \
    && rm -rf /var/lib/apt/lists/*
