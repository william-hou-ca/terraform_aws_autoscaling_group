provider "aws" {
  # Configuration options
  region = "ca-central-1"
}


###########################################################################
#
# Use this data source to get the amazon linux 2 ID of a registered AMI for use in other resources.
#
###########################################################################

data "aws_ami" "amz2" {
  most_recent = true
  owners      = ["amazon"] # Canonical

  # more filter conditions are describled in the followed web link
  # https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-images.html
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

###########################################################################
#
# get datas from the region
#
###########################################################################

data "aws_availability_zones" "available_zones" {
  state = "available"
}

# search a security group in the default vpc and it will be used in ec2 instance's security_groups
data "aws_security_groups" "default_sg" {
  filter {
    name   = "group-name"
    values = ["*SG-STRICT-ACCESS*"]
  }
}
