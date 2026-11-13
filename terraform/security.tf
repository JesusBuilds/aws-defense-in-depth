resource "aws_security_group" "web" {
  name        = "${var.project}-web"
  description = "Web tier: HTTP from internet, metrics from monitor only"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "monitor" {
  name        = "${var.project}-monitor"
  description = "Monitor tier: no inbound, reached through SSM only"
  vpc_id      = aws_vpc.main.id
}
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "web_metrics" {
  security_group_id            = aws_security_group.web.id
  description                  = "node_exporter from monitor SG only"
  referenced_security_group_id = aws_security_group.monitor.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS out for packages, images and SSM"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "monitor_https" {
  security_group_id = aws_security_group.monitor.id
  description       = "HTTPS out for packages, images and SSM"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "monitor_to_web_http" {
  security_group_id            = aws_security_group.monitor.id
  description                  = "Blackbox probe to web tier"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "monitor_to_web_metrics" {
  security_group_id            = aws_security_group.monitor.id
  description                  = "Scrape node_exporter on web tier"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
}
locals {
  ec2_assume = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role" "web" {
  name               = "${var.project}-web"
  assume_role_policy = local.ec2_assume
}
resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web"
  role = aws_iam_role.web.name
}


resource "aws_iam_role" "monitor" {
  name               = "${var.project}-monitor"
  assume_role_policy = local.ec2_assume
}
resource "aws_iam_role_policy_attachment" "monitor_ssm" {
  role       = aws_iam_role.monitor.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "random_password" "grafana" {
  length  = 20
  special = false
}
resource "aws_ssm_parameter" "grafana_admin" {
  name  = "/${var.project}/grafana-admin-password"
  type  = "SecureString"
  value = random_password.grafana.result
}
resource "aws_iam_role_policy" "monitor_secret" {
  name = "read-grafana-secret"
  role = aws_iam_role.monitor.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = aws_ssm_parameter.grafana_admin.arn
    }]
  })
}
resource "aws_iam_instance_profile" "monitor" {
  name = "${var.project}-monitor"
  role = aws_iam_role.monitor.name
}