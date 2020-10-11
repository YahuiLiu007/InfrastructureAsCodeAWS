terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                  = "us-west-1"
  shared_credentials_file = "credentials"
}




#create a vpc.




resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}




#create 3 subnets in vpc.




resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.sn1_cidr
  availability_zone = var.sn1_az
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.sn2_cidr
  availability_zone = var.sn2_az
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet2"
  }
}

resource "aws_subnet" "public_subnet3" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.sn3_cidr
  availability_zone = var.sn3_az
  map_public_ip_on_launch = true


  tags = {
    Name = "public_subnet3"
  }
}




# create a gateway
# tip: the instance would need it so that there  should be a 'depend on'




resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.gtw_name
  }
}



#create a route table with a 'route' to internet.




resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = var.rtt_name
  }
}




#associate route table with subnets.




resource "aws_route_table_association" "sn1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "sn2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "sn3" {
  subnet_id      = aws_subnet.public_subnet3.id
  route_table_id = aws_route_table.rt.id
}




#create a security group with rules.




resource "aws_security_group" "web" {
  name        = "web"
  description = "security group for web"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http annother access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = var.vpc_sg_name
  }
}



# create RDS security group



resource "aws_security_group" "DB" {
  name        = "DB"
  description = "security group for DB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "DB postgres port"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = var.db_sg_name
  }

}



#create DB 2 subnets



resource "aws_subnet" "DB_subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.db_sn1_cidr
  availability_zone = var.db_sn1_az
  tags = {
    Name = "DB_subnet1"
  }
}
resource "aws_subnet" "DB_subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.db_sn2_cidr
  availability_zone = var.db_sn2_az
  tags = {
    Name = "DB_subnet2"
  }
}



# create DB subnet group



resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.DB_subnet1.id, aws_subnet.DB_subnet2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

#associate route table with subnets.

resource "aws_route_table_association" "sn4" {
  subnet_id      = aws_subnet.DB_subnet1.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "sn5" {
  subnet_id      = aws_subnet.DB_subnet2.id
  route_table_id = aws_route_table.rt.id
}

#create RDS instance

resource "aws_db_instance" "mydb" {
  allocated_storage    = var.db_storage
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  name                 = var.db_name
  username             = var.db_username
  password             = var.db_password
  vpc_security_group_ids = [aws_security_group.DB.id]
  multi_az = false
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.default.id
  skip_final_snapshot = true
}


#Create a application load banlancer

resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "security group for LB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "lb HTTP port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "LB_security_group"
  }

}

resource "aws_lb_target_group" "lbtg" {
  name     = "tf-lbtg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = var.lb_listener_port
  protocol          = var.lb_listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lbtg.arn
  }
}

resource "aws_lb" "mylb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id,aws_subnet.public_subnet3.id]

 
  ip_address_type = "ipv4"


  tags = {
    Environment = "production"
  }
}



#create a aws_launch_configurtation

resource "aws_launch_configuration" "as_conf" {
  name_prefix = "auto-scaled-instance-"
  image_id      = var.image_id
  instance_type = var.instance_type
  key_name = var.key_name
  lifecycle {
    create_before_destroy = true
  }
  security_groups = [aws_security_group.web.id]
  associate_public_ip_address = true
  depends_on = [aws_internet_gateway.gw]
   user_data = <<-EOF
    #! /bin/bash
    /bin/echo "RDS_USERNAME=${var.db_username}" >> /etc/environment
    /bin/echo "RDS_PASSWORD=${var.db_password}" >> /etc/environment
    /bin/echo "RDS_DBNAME=${var.db_name}" >> /etc/environment
    /bin/echo "RDSHOST_NAME=${aws_db_instance.mydb.address}" >> /etc/environment
    sudo -u ubuntu git clone "https://""${var.gitusername}":"${var.gitpassword}""${var.gitrepo}" /home/ubuntu/webapp
    sudo -u ubuntu pip3 install -r /home/ubuntu/webapp/requirements.txt
    cd /home/ubuntu/webapp/
    nohup sudo -u ubuntu python3 /home/ubuntu/webapp/views.py &
    EOF

}
resource "aws_autoscaling_group" "myasg" {
  name                 = "terraform-asg"
  min_size             = 1
  max_size             = 2
  depends_on           = [aws_lb.mylb]
  target_group_arns    = [aws_lb_target_group.lbtg.arn]
  launch_configuration = aws_launch_configuration.as_conf.name
  lifecycle {
    create_before_destroy = true
  }
  health_check_grace_period = 300
  health_check_type         = "ELB"
  vpc_zone_identifier = [aws_subnet.public_subnet1.id,aws_subnet.public_subnet3.id]
  default_cooldown = 100
}
resource "aws_autoscaling_policy" "up" {
  name                   = "terraform-as-policy-up"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 100
  autoscaling_group_name = aws_autoscaling_group.myasg.name
}
resource "aws_autoscaling_policy" "down" {
  name                   = "terraform-as-policy-down"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 100
  autoscaling_group_name = aws_autoscaling_group.myasg.name
}
resource "aws_cloudwatch_metric_alarm" "upalarm" {
  alarm_name          = "cloud-watch-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.myasg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization at 70%"
  alarm_actions     = [aws_autoscaling_policy.up.arn]
}
resource "aws_cloudwatch_metric_alarm" "downalarm" {
  alarm_name          = "cloud-watch-down-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "40"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.myasg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization at 40%"
  alarm_actions     = [aws_autoscaling_policy.down.arn]
}

