resource "aws_lb" "app" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_id]
  subnets            = var.subnet_ids
  tags               = { Name = var.name }
}



resource "aws_lb_target_group" "tg_80" {
  name     = "${var.name}-tg-80"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = var.tags
}

resource "aws_lb_target_group" "tg_443" {
  name     = "${var.name}-tg-443"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTPS"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = var.tags
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_80.arn
  }
}

#Import SSL Certificate into AWS Certificate Manager
resource "aws_acm_certificate" "imported_cert" {
  private_key       = file("certs/key.pem")
  certificate_body  = file("certs/certificate.pem")
  certificate_chain = file("certs/certificate_chain.pem")

  tags = {
    Name = "my-imported-cert"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"  # You can pick another if needed

  certificate_arn = aws_acm_certificate.imported_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_443.arn
  }
}


resource "aws_lb_target_group_attachment" "web1_80" {
  count             = length(var.instance_ids)
  target_group_arn  = aws_lb_target_group.tg_80.arn
  target_id         = var.instance_ids[count.index]
  port              = var.target_group_port
}

resource "aws_lb_target_group_attachment" "web1_443" {
  count             = length(var.instance_ids)
  target_group_arn  = aws_lb_target_group.tg_443.arn
  target_id         = var.instance_ids[count.index]
  port              = var.target_group_port
}


