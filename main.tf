# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# create all the resources to deploy webserver in an auto scaling group with elb
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ----------------------------------------------------------------------------------------------------------------------
# require specific terraform version or higher
----------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.12"
}


provider "aws" {
  region = "us-east-2"
}

# ---------------------------------------------------------------------------------------------------------------------
# get the list of availability zones in the current region
# ---------------------------------------------------------------------------------------------------------------------

data "aws_availability_zones" "all" {}


#---------------------------------------------------------------------------------------------------
# adding iam role
#-------------------------------------------------------------------------------------------------

resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "tag-value"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# create instance Profile
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.test_role.name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# adding IAM Policies
# to give full access to S3 bucket
# ---------------------------------------------------------------------------------------------------------------------


resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = "${aws_iam_role.test_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


# ---------------------------------------------------------------------------------------------------------------------
# create the auto scaling group
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "example-autoscaling" {
  name = "example-autoscaling"
  launch_configuration = aws_launch_configuration.example.id
  availability_zones   = data.aws_availability_zones.all.names

  min_size = 1
  max_size = 3

  load_balancers    = [aws_elb.example.name]
  health_check_type = "elb"

  tag {
    key                 = "name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# create a launch configuration that defines each ec2 instance in the asg
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "example" {
  # ubuntu server 18.04 lts
  image_id        = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-eof
              #! /bin/bash
              sudo yum update
              sudo yum install -y httpd
              sudo chkconfig httpd on
              sudo service httpd start
              echo "<h1>Deployed via Terraform wih ELB</h1>" | sudo tee /var/www/html/index.html
              eof

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# create the security group that's applied to each ec2 instance in the asg
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  # inbound http from anywhere
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# create an elb to route traffic across the auto scaling group
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elb" "example" {
  name               = "${aws_autoscaling_group.example-autoscaling.name}"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names

  health_check {
    target              = "http:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # this adds a listener for incoming http requests.
  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# create a security group that controls what traffic an go in and out of the elb
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  # allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound http from anywhere
  ingress {
    from_port   = var.elb_port
    to_port     = var.elb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# scale up alarm

resource "aws_autoscaling_policy" "example-cpu-policy" {

    name = "example-cpu-policy"
    autoscaling_group_name = "${aws_autoscaling_group.example-autoscaling.name}"
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = "1"
    cooldown = "300"
    policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "example-cpu-alarm" {

    alarm_name = "example-cpu-alarm"
    alarm_description = "example-cpu-alarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "80"
    dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.example-autoscaling.name}"

    }
    actions_enabled = true
    alarm_actions = ["${aws_autoscaling_policy.example-cpu-policy.arn}"]
}

# scale down alarm
resource "aws_autoscaling_policy" "example-cpu-policy-scaledown" {
    name = "example-cpu-policy-scaledown"
    autoscaling_group_name = "${aws_autoscaling_group.example-autoscaling.name}"
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = "-1"
    cooldown = "300"
    policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "example-cpu-alarm-scaledown" {
    alarm_name = "example-cpu-alarm-scaledown"
    alarm_description = "example-cpu-alarm-scaledown"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "60"
    dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.example-autoscaling.name}"
    }
    actions_enabled = true
    alarm_actions = ["${aws_autoscaling_policy.example-cpu-policy-scaledown.arn}"]
    }

resource "aws_s3_bucket_object" "file_upload" {
    bucket = "my_bucket"
    key    = "my_bucket_key"
    source = "/var/www/html/index.html"
    etag   = "${filemd5("index.html")}"
}