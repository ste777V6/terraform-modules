# Everything the public entry point needs: the ALB, its listeners, the
# blue/green target groups, the TLS certificate and the access-log bucket.
# ACM and the log bucket are only used by the ALB, so they live here rather
# than in modules of their own.

locals {
  target_groups = toset(["blue", "green"])
}

# ---------------------------------------------------------------------------
# TLS certificate (validated via an external DNS provider)
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  domain_name       = var.certificate_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Waits until the CNAME (see outputs) exists at the external DNS provider and
# AWS has issued the certificate, so the HTTPS listener never gets a pending cert.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_name]

  timeouts {
    create = var.certificate_validation_timeout
  }
}

# ---------------------------------------------------------------------------
# Access-log bucket
# ---------------------------------------------------------------------------

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "logs" {
  bucket        = var.log_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowELBLogDelivery"
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/*"
      },
      {
        Sid       = "AllowELBLogDeliveryACLCheck"
        Effect    = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      }
    ]
  })

  # The public access block must be in place before the policy is attached
  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# ---------------------------------------------------------------------------
# Target groups (blue = live, green = next version for blue/green deploys)
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "this" {
  for_each = local.target_groups

  name        = "${var.name}-tg-${each.key}"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# ---------------------------------------------------------------------------
# Load balancer and listeners
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.security_group_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = var.log_prefix
    enabled = true
  }

  # AWS checks it can write to the bucket when logging is enabled,
  # so the bucket policy must exist first. Wait also for the ACM certificate to be issued so the HTTPS listener can be created.
  depends_on = [aws_s3_bucket_policy.logs]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["blue"].arn
  }

  depends_on = [aws_acm_certificate_validation.this]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  depends_on = [aws_acm_certificate_validation.this]
}
