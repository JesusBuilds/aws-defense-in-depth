FROM jenkins/jenkins:lts-jdk17
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv unzip curl jq git ca-certificates && rm -rf /var/lib/apt/lists/*
ARG TF_VERSION=1.10.5
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip -o /tmp/tf.zip && unzip /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip
ARG GL_VERSION=8.21.2
RUN curl -fsSL https://github.com/gitleaks/gitleaks/releases/download/v${GL_VERSION}/gitleaks_${GL_VERSION}_linux_x64.tar.gz | tar -xz -C /usr/local/bin gitleaks
RUN python3 -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir checkov
ENV PATH="/opt/venv/bin:${PATH}"
RUN curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip && unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip
USER jenkins