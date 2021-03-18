# terraform_aws_autoscaling_group
In the main.tf, There are some datas fetched from aws. The file asg_basic.tf and asg_advanced.tf will use it.

In the asg_basic.tf, its topics are:
  1. launch configuration
  2. schedule policy
  3. scaling policy
  4. autoscaling group with the upper options.

In the asg_advanced.tf, it will cover:
  1. launch template
  2. create a role and instance profile attached to launch template
  3. an autoscaling group using launch template with the features: instance refresh and interpolated tags
  4. an asg uses mixed Instances Policy using launch_template
  5. an asg with mixed Instances Policy using instances_distribution and capability rebalance

You could see topology in the file graph.svg!