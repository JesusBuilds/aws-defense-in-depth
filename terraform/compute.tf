data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.web.name
  user_data                   = file("${path.module}/templates/web_userdata.sh")
  user_data_replace_on_change = true
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }
  tags = { Name = "${var.project}-web" }
}
resource "aws_instance" "monitor" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.monitor.id]
  iam_instance_profile   = aws_iam_instance_profile.monitor.name


  user_data = templatefile("${path.module}/templates/monitor_userdata.sh.tftpl", {
    web_ip      = aws_instance.web.private_ip
    region      = var.region
    secret_name = aws_ssm_parameter.grafana_admin.name
  })
  user_data_replace_on_change = true
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 12
  }
  # NAT route and IAM policy must exist before first boot or the install fails
  depends_on = [aws_route_table_association.private,
  aws_iam_role_policy.monitor_secret]
  tags = { Name = "${var.project}-monitor" }
}