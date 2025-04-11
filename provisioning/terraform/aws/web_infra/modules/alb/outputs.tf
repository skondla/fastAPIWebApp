output "lb_arn" { value = aws_lb.app.arn }
output "tg_arn" { value = aws_lb_target_group.tg_80.arn }
output "tg_443_arn" { value = aws_lb_target_group.tg_443.arn }
output "lb_dns_name" { value = aws_lb.app.dns_name }
output "lb_id" { value = aws_lb.app.id }
output "tg_id" { value = aws_lb_target_group.tg_80.id }
output "tg_443_id" { value = aws_lb_target_group.tg_443.id }

output "target_group_arn" {
  value = aws_lb_target_group.tg_80.arn
}

output "tags" {
  value = aws_lb.app.tags
}
