output "web_loadbalancer_url" {
  value = aws_lb.web.dns_name
}

output "instance_id" {
  value = data.aws_ami.latest_aws_linux.id
}
