provider "aws" {
  region = "ca-central-1"

  default_tags {
    tags = {
      Owner   = "Danny Diemiekhin"
      Created = "Terraform"
    }
  }
}
#---------------------------------

data "aws_availability_zones" "working" {}

data "aws_ami" "latest_aws_linux" {
  owners      = ["137112412989"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}
#--------------------------------------------------
resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.working.names[0]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.working.names[1]
}
#------------------------------
resource "aws_security_group" "web-server" {
  name   = "Web Security Group"
  vpc_id = aws_default_vpc.default.id
  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Web Security Group"
  }
}

#----------------------------------
resource "aws_launch_template" "web" {
  name                   = "WebServer-Highly-Available"
  image_id               = data.aws_ami.latest_aws_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web-server.id]
  user_data              = filebase64("${path.module}/user_data.sh")
  key_name               = "Canada"
}

#------------------------------------------

resource "aws_autoscaling_group" "web" {
  name                = "WebServer-Highly-Avaliable-ASG-Ver-${aws_launch_template.web.latest_version}"
  min_size            = 2
  max_size            = 2
  min_elb_capacity    = 2
  health_check_type   = "ELB"
  vpc_zone_identifier = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  target_group_arns   = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  dynamic "tag" {
    for_each = {
      name    = "WebServer in ASG-Version${aws_launch_template.web.latest_version}"
      TAGKEY  = "Test-Web"
      Project = "DevOps"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
#---------------------
resource "aws_lb" "web" {
  name               = "WebServer-HighlyAvaliable-ALB"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-server.id]
  subnets            = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
}

resource "aws_lb_target_group" "web" {
  name                 = "WebServer-HighlyAvaliable-TG"
  vpc_id               = aws_default_vpc.default.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 10 # time in seconds 
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}


