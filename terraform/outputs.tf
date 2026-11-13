output "web_public_ip" {
  value = aws_instance.web.public_ip
}
output "web_instance_id" {
  value = aws_instance.web.id
}
output "monitor_instance_id" {
  value = aws_instance.monitor.id
}
output "grafana_password_parameter" {
  value = aws_ssm_parameter.grafana_admin.name
}