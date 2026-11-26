output "alb_dns_name" {
  value = aws_lb.app.dns_name
}
output "app_url" {
  value = "${var.certificate_arn == "" ? "http" : "https"}://${aws_lb.app.dns_name}"
}
output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
output "cluster_name" {
  value = aws_ecs_cluster.main.name
}
output "service_name" {
  value = aws_ecs_service.app.name
}
output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
