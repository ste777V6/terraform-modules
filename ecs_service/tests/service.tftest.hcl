mock_provider "aws" {
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam:us-east-1:123456789012:policy/p"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam:us-east-1:123456789012:role/r"
    }
  }
  mock_data "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam:us-east-1:123456789012:role/ecsTaskExecutionRole"
      name = "ecsTaskExecutionRole"
    }
  }
  mock_data "aws_elb_service_account" {
    defaults = {
      arn = "arn:aws:iam::127311923021:root"
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
      name   = "us-east-1"
    }
  }
  mock_resource "aws_lb" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/x/1"
      arn_suffix = "app/x/1"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/x/1"
      arn_suffix = "targetgroup/x/1"
    }
  }
  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/x/1/2"
    }
  }
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/1"
    }
  }
  mock_resource "aws_acm_certificate_validation" {
    defaults = {
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/1"
    }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-AbCdEf"
      id  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-AbCdEf"
    }
  }
  mock_resource "aws_service_discovery_http_namespace" {
    defaults = {
      arn = "arn:aws:servicediscovery:us-east-1:123456789012:namespace/ns-1"
    }
  }
  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:cluster/c"
      id  = "arn:aws:ecs:us-east-1:123456789012:cluster/c"
    }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/t:1"
    }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::b"
    }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/ecs/x"
    }
  }
}

variables {
  cluster_id                    = "arn:aws:ecs:us-east-1:123456789012:cluster/c"
  cluster_name                  = "c"
  subnet_ids                    = ["subnet-1", "subnet-2"]
  security_group_ids            = ["sg-1"]
  service_connect_namespace_arn = "arn:aws:servicediscovery:us-east-1:123456789012:namespace/ns-1"
}

run "backend" {
  command = plan
  variables {
    name            = "app-backend"
    container_name  = "backend"
    image           = "img:1"
    container_port  = 8000
    command         = ["sh", "-c", "flask db upgrade && exec gunicorn run:app"]
    environment     = { FLASK_APP = "run.py" }
    secrets         = { DATABASE_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-AbCdEf" }
    service_connect = { dns_name = "backend" }
  }
  assert {
    condition     = length(aws_ecs_service.this.load_balancer) == 0
    error_message = "backend must not be behind the ALB"
  }
  assert {
    condition     = aws_ecs_service.this.service_connect_configuration[0].service[0].discovery_name == "backend" && aws_ecs_service.this.service_connect_configuration[0].service[0].port_name == "http"
    error_message = "backend must be published as backend on port name http"
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings[0].name == "http"
    error_message = "port mapping name must match Service Connect port_name"
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].command[0] == "sh"
    error_message = "command override missing"
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets[0].name == "DATABASE_URL"
    error_message = "DATABASE_URL secret missing"
  }
  assert {
    condition     = length(aws_appautoscaling_policy.request_count) == 0 && length(aws_iam_policy.secrets_read) == 1
    error_message = "backend: no request-count scaling, one secrets policy"
  }
  assert {
    condition     = output.service_connect_url == "http://backend:8000"
    error_message = "service_connect_url wrong"
  }
}

run "frontend" {
  command = plan
  variables {
    name           = "app-frontend"
    container_name = "frontend"
    image          = "img:1"
    container_port = 80
    environment    = { PORT = "80", BACKEND_URL = "http://backend:8000" }
    load_balancer = {
      target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/b/1"
      resource_label   = "app/x/1/targetgroup/b/1"
    }
  }
  assert {
    condition     = length(aws_ecs_service.this.load_balancer) == 1
    error_message = "frontend must be behind the ALB"
  }
  assert {
    condition     = length(aws_ecs_service.this.service_connect_configuration[0].service) == 0 && aws_ecs_service.this.service_connect_configuration[0].enabled
    error_message = "frontend must be a Service Connect client only"
  }
  assert {
    condition     = !contains(keys(jsondecode(aws_ecs_task_definition.this.container_definitions)[0]), "command")
    error_message = "frontend must keep the image CMD"
  }
  assert {
    condition     = length(aws_appautoscaling_policy.request_count) == 1 && length(aws_iam_policy.secrets_read) == 0
    error_message = "frontend: request-count scaling, no secrets policy"
  }
  assert {
    condition     = output.service_connect_url == null
    error_message = "frontend should not publish a URL"
  }
}
