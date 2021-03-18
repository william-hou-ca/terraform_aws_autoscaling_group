###########################################################################
#
# create a launch template for autoscaling group
#
###########################################################################

resource "aws_launch_template" "lt" {
  name_prefix = "terraform-lt"

  #Specify volumes to attach to the instance besides the volumes specified by the AMI
  block_device_mappings {
    device_name = "/dev/sdb"

    ebs {
      volume_size = 5
      delete_on_termination = true
    }
  }
/*
  capacity_reservation_specification {
    capacity_reservation_preference = "none"
  }

  cpu_options {
    core_count       = 4
    threads_per_core = 2
  }

  credit_specification {
    cpu_credits = "standard"
  }

  disable_api_termination = true

  ebs_optimized = true

  elastic_gpu_specifications {
    type = "test"
  }

  elastic_inference_accelerator {
    type = "eia1.medium"
  }
*/
  # attach a role to instances.
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance_profile.arn
  }

  image_id = data.aws_ami.amz2.id

  instance_initiated_shutdown_behavior = "terminate"

/*
  instance_market_options {
    market_type = "spot"
  }
*/

  instance_type = "t2.micro"

  #kernel_id = "test"

  key_name = "key-hr123000" #key paire name exists in my aws.You should use your owned key name

/*
  license_specification {
    license_configuration_arn = "arn:aws:license-manager:eu-west-1:123456789012:license-configuration:lic-0123456789abcdef0123456789abcdef"
  }
*/

  metadata_options {
    # Whether the metadata service is available. Can be "enabled" or "disabled"
    http_endpoint               = "enabled"
    # Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2 (IMDSv2). Can be "optional" or "required"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  monitoring {
    # If true, the launched EC2 instance will have detailed monitoring enabled.
    enabled = false
  }

/*
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination = true
    device_index = 0
    security_groups = data.aws_security_groups.default_sg.ids
  }


  placement {
    availability_zone = "us-west-2a"
  }

  ram_disk_id = "test"
*/

  # when you use network_interfaces block, comment this option and configure sg in that block
  vpc_security_group_ids = data.aws_security_groups.default_sg.ids

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "ec2_from_launchTemplate"
    }
  }

  user_data = filebase64("./ec2_init.sh")
}


###########################################################################
#
# create a role and instance profile for launch template
#
###########################################################################

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "terraform_instance_profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "terraform_role"
  path = "/"

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
}


###########################################################################
#
# create an autoscaling group using launch template
# With Latest Version Of Launch Template
#
###########################################################################


variable "extra_tags" {
  default = [
    {
      key                 = "Foo"
      value               = "Bar"
      propagate_at_launch = true
    },
    {
      key                 = "Baz"
      value               = "Bam"
      propagate_at_launch = true
    },
  ]
}

resource "aws_autoscaling_group" "asg_lt" {
  availability_zones = data.aws_availability_zones.available_zones.names
  desired_capacity   = 1
  max_size           = 2
  min_size           = 1

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  #  A refresh will always be triggered by a change in any of launch_configuration, launch_template, or mixed_instances_policy
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
    #triggers = ["tag"]
  }

  # Interpolated tags
  tags = concat(
    [
      {
        "key"                 = "interpolation1"
        "value"               = "value3"
        "propagate_at_launch" = true
      },
      {
        "key"                 = "interpolation2"
        "value"               = "value4"
        "propagate_at_launch" = true
      },
    ],
    var.extra_tags,
  )
}

###########################################################################
#
# create an autoscaling group using launch template
# Mixed Instances Policy using launch_template
#
###########################################################################

resource "aws_launch_template" "lt_mip" {
  name_prefix   = "tf-lt-mip"
  image_id      = data.aws_ami.amz2.id
  instance_type = "c5.large"
}

resource "aws_launch_template" "lt_mip_others" {
  name_prefix   = "tf-lt-mip"
  image_id      = data.aws_ami.amz2.id
  # other configuration different to launch template lt_mip
}

resource "aws_autoscaling_group" "asg_lt_mip" {
  count = 0 #if you want to run this example, comment this row
  availability_zones = data.aws_availability_zones.available_zones.names
  desired_capacity   = 1
  max_size           = 2
  min_size           = 1

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.lt_mip.id
        version = "$Default"
      }

      override {
        instance_type     = "c4.large"
        weighted_capacity = "3"
        launch_template_specification {
          launch_template_id = aws_launch_template.lt_mip_others.id
        }
      }

      override {
        instance_type     = "c3.large"
        weighted_capacity = "2"
      }
    }
  }
}

###########################################################################
#
# create an autoscaling group using launch template
# Mixed Instances Policy using instances_distribution and capability rebalance
#
###########################################################################

resource "aws_autoscaling_group" "asg_id" {
  count = 0 #if you want to run this example, comment this row
  capacity_rebalance  = true
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  availability_zones = data.aws_availability_zones.available_zones.names

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.lt_mip.id
      }

      override {
        instance_type     = "c4.large"
        weighted_capacity = "3"
      }

      override {
        instance_type     = "c3.large"
        weighted_capacity = "2"
      }
    }
  }
}