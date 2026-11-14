#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

dnf install -y docker
systemctl enable --now docker

mkdir -p /opt/site
cat > /opt/site/index.html <<'HTML'
<!doctype html>
<html><head><title>Defense in Depth Lab</title></head>
<body style="font-family:sans-serif">
<h1>Defense in Depth on AWS</h1>
<p>Deployed by Terraform through a Jenkins pipeline.</p>
</body></html>
HTML

docker run -d --name web --restart always -p 80:80 -v /opt/site:/usr/share/nginx/html:ro nginx:stable
docker run -d --name node-exporter --restart always --net=host --pid=host -v /:/host:ro,rslave quay.io/prometheus/node-exporter:latest --path.rootfs=/host
