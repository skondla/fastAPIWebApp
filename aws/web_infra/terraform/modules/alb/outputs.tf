output "lb_arn" { value = aws_lb.app.arn }
output "tg_arn" { value = aws_lb_target_group.tg.arn }
