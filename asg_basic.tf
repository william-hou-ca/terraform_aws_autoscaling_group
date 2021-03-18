###########################################################################
#
# create a launch configuration for autoscaling group
#
###########################################################################

resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "terraform-lc-example-"
  image_id      = data.aws_ami.amz2.id
  instance_type = "t2.micro"

  #Using with Spot Instances
  #spot_price    = "0.001"

  key_name = "key-hr123000" #key paire name exists in my aws.You should use your owned key name

  associate_public_ip_address = true
  security_groups = data.aws_security_groups.default_sg.ids

  user_data = <<EOF
            #! /bin/sh
            sudo yum update -y
            sudo amazon-linux-extras install -y nginx1
            sudo systemctl start nginx
            sudo curl -s http://169.254.169.254/latest/meta-data/local-hostname >/tmp/hostname.html
            sudo mv /tmp/hostname.html /usr/share/nginx/html/index.html
            sudo chmod a+r /usr/share/nginx/html/index.html
            EOF

  # root block device configuration
  /*
  root_block_device {
    delete_on_termination = true
    encrypted = false
    volume_size = 8
    volume_type = "gp2"
  }
  */
  
  #you could add additional disks by using ebs_block_device block. same as root_block_device.
  /*
  ebs_block_device {
    device_name = "web_ebs_device1" #required
    delete_on_termination = true
    encrypted = false
    volume_size = 8
    volume_type = "gp2"

    #iops - (Optional) The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    iops = 100
  }
  */

  lifecycle {
    #Launch Configurations cannot be updated after creation with the Amazon Web Service API. 
    #In order to update a Launch Configuration, Terraform will destroy the existing resource and create a replacement. 
    #In order to effectively use a Launch Configuration resource with an AutoScaling Group resource, 
    #it's recommended to specify create_before_destroy in a lifecycle block. 
    #Either omit the Launch Configuration name attribute, or specify a partial name with name_prefix
    create_before_destroy = true
  }
}

###########################################################################
#
# create an autoscaling group using launch configuration
#
###########################################################################

resource "aws_autoscaling_group" "web" {
   
  name                 = "terraform-asg-example"
  launch_configuration = aws_launch_configuration.as_conf.name

  max_size                  = 4
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  # when you attach asg to an elb, use the value ELB to replace EC2
  health_check_type         = "EC2"

  # when you use your self vpc and subnets, use the following option to indicate subnet list id
  # vpc_zone_identifier = [aws_subnet.example1.id, aws_subnet.example2.id]

  # use availability zones in the default vpc
  availability_zones = data.aws_availability_zones.available_zones.names

  #When a configuration change requires replacing instances,
  #With an instance refresh, it's easier to update the instances in your Auto Scaling group. 
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup = 30
    }
  }

  tag {
    key                 = "env"
    value               = "test"
    # when propagate is true, this tag will be attached to instances.
    propagate_at_launch = true
  }

  tag {
    key                 = "configureType"
    value               = "launchConfiguration"
    propagate_at_launch = false
  }
}

###########################################################################
#
# configure an autoscaling policy
#
###########################################################################
resource "aws_autoscaling_policy" "asp" {
  name                   = "terraform-asp"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.web.name


  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

###########################################################################
#
# configure an autoscaling schedule
#
###########################################################################
resource "aws_autoscaling_schedule" "ass" {
  scheduled_action_name  = "terraform-ass"
  min_size               = -1
  max_size               = 3
  desired_capacity       = 1
  start_time             = "2022-12-11T23:00:00Z"
  #end_time               = "2016-12-12T06:00:00Z"
  recurrence = "0 0 * * *"
  autoscaling_group_name = aws_autoscaling_group.web.name
}

###########################################################################
#
# get instances from autoscaling group
#
###########################################################################
data "aws_instances" "asg_instances" {
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.web.name
  }

  instance_state_names = ["running"]
}

output "asg_instances_ip" {
  value = data.aws_instances.asg_instances.public_ips
}