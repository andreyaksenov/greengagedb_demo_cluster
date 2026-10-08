FROM ubuntu:22.04

ARG GREENGAGE_VERSION=7.5.1
ARG PXF_VERSION=6.17.5
ARG GPBACKUP_VERSION=1.31.2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install base tools, OpenSSH, JDK 17 required by PXF, and pip used in PL/Python examples.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg locales sudo vim python3-pip \
        openssh-server openssh-client openjdk-17-jdk-headless \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Add the Greengage DB APT repository and install Greengage DB, PXF, and gpbackup.
# The gpbackup package links its utilities to the bin directory of the installed Greengage DB.
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://greengagedb.org/repositories/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/greengagedb.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/greengagedb.gpg] https://greengagedb.org/repositories/ubuntu/22.04/x86_64 greengagedb main' \
        > /etc/apt/sources.list.d/greengagedb.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        greengage7=${GREENGAGE_VERSION} \
        pxf-server=${PXF_VERSION} \
        pxf-cli=${PXF_VERSION} \
        pxf-fdw7=${PXF_VERSION} \
        gpbackup=${GPBACKUP_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Create the gpadmin administrative user.
RUN groupadd gpadmin \
    && useradd -r -m -g gpadmin -s /bin/bash gpadmin \
    && echo 'gpadmin:password' | chpasswd \
    && echo 'gpadmin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/gpadmin \
    && chmod 0440 /etc/sudoers.d/gpadmin \
    && printf '%s\n' \
        'gpadmin soft nofile 524288' \
        'gpadmin hard nofile 524288' \
        'gpadmin soft nproc 150000' \
        'gpadmin hard nproc 150000' \
        > /etc/security/limits.d/gpadmin.conf

# Configure sshd and generate an SSH key pair for gpadmin.
# All hosts are built from the same image and share the gpadmin key pair,
# so authorizing the key enables passwordless SSH between the hosts.
# Host key checking is disabled because host keys change on every image rebuild,
# while known_hosts files persist in the home directory volumes.
RUN ssh-keygen -A \
    && mkdir -p /run/sshd \
    && sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?MaxStartups .*/MaxStartups 100/' /etc/ssh/sshd_config \
    && printf '%s\n' \
        'Host *' \
        '    StrictHostKeyChecking no' \
        '    UserKnownHostsFile /dev/null' \
        '    LogLevel ERROR' \
        > /etc/ssh/ssh_config.d/demo_cluster.conf \
    && sudo -u gpadmin ssh-keygen -t rsa -b 4096 -N '' -f /home/gpadmin/.ssh/id_rsa \
    && sudo -u gpadmin cp /home/gpadmin/.ssh/id_rsa.pub /home/gpadmin/.ssh/authorized_keys \
    && chmod 0600 /home/gpadmin/.ssh/authorized_keys
