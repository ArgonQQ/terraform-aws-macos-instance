# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Get current public IP address (only if SSH is enabled)
data "http" "my_public_ip" {
  count = var.enable_ssh ? 1 : 0
  url   = "https://checkip.amazonaws.com"
}

locals {
  # Only set my_public_ip if SSH is enabled, otherwise use an empty string
  my_public_ip = var.enable_ssh ? "${chomp(data.http.my_public_ip[0].response_body)}/32" : ""

  # Combine auto-detected IP with any additional IPs specified
  # If allow_ssh_from_anywhere is true, include 0.0.0.0/0 for emergency access
  ssh_cidr_blocks = var.enable_ssh ? (
    var.allow_ssh_from_anywhere ? ["0.0.0.0/0"] : distinct(concat([local.my_public_ip], var.additional_ssh_cidr_blocks))
  ) : []
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "additional_ssh_cidr_blocks" {
  description = "Additional CIDR blocks to allow SSH access from (in case auto-detection fails)"
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_anywhere" {
  description = "If true, allows SSH access from any IP address (0.0.0.0/0) - use only temporarily in emergencies"
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "Availability zone for dedicated hosts"
  type        = string
  default     = "ap-southeast-2a"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "macos-instance"
}

variable "macos_ami_id" {
  description = "AMI ID for macOS instance (e.g., macOS Sequoia)"
  type        = string
  default     = "" # No default AMI ID - user must provide their own
}

variable "enable_ssm" {
  description = "Whether to enable SSM access to the instance"
  type        = bool
  default     = true
}

variable "ssm_run_as_user" {
  description = "User that SSM should run as"
  type        = string
  default     = "ec2-user"
}

variable "enable_ssh" {
  description = "Whether to enable SSH access to the instance"
  type        = bool
  default     = false

  validation {
    condition     = var.enable_ssh || var.enable_ssm
    error_message = "At least one of SSH or SSM access must be enabled for the instance."
  }
}


# Generate SSH Key Pair (only if SSH is enabled)
resource "tls_private_key" "macos_key" {
  count = var.enable_ssh ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file (only if SSH is enabled)
resource "local_file" "private_key" {
  count = var.enable_ssh ? 1 : 0

  content         = tls_private_key.macos_key[0].private_key_pem
  filename        = "${path.module}/macos-instance-key.pem"
  file_permission = "0600"
}

# EC2 Key Pair (only if SSH is enabled)
resource "aws_key_pair" "macos_key" {
  count = var.enable_ssh ? 1 : 0

  key_name   = "macos-instance-key"
  public_key = tls_private_key.macos_key[0].public_key_openssh

  tags = {
    Name = "macOS Instance Key Pair"
  }
}

# Host Resource Group for macOS dedicated hosts
resource "aws_licensemanager_license_configuration" "license_config" {
  name                     = "MyRequiredLicense"
  description              = "Pass through configuration for Host Resource Group"
  license_count            = 32
  license_count_hard_limit = false
  license_counting_type    = "Core"
}

resource "aws_resourcegroups_group" "aws_resourcegroups_licence_group" {
  name = "LicenceManagerResourceGroup"
  configuration {
    type = "AWS::EC2::HostManagement"
    parameters {
      name   = "allowed-host-based-license-configurations"
      values = [aws_licensemanager_license_configuration.license_config.arn]
    }
    parameters {
      name   = "auto-allocate-host"
      values = [true]
    }
    parameters {
      name   = "auto-release-host"
      values = [true]
    }
    parameters {
      name   = "auto-host-recovery"
      values = [true]
    }
    parameters {
      name = "allowed-host-families"
      values = [
        "mac2",
        "mac2-m2",
        "mac2-m2pro",
      ]
    }
  }
  configuration {
    type = "AWS::ResourceGroups::Generic"
    parameters {
      name   = "allowed-resource-types"
      values = ["AWS::EC2::Host"]
    }
    parameters {
      name   = "deletion-protection"
      values = ["UNLESS_EMPTY"]
    }
  }

  # Prevent changes to configuration on every run
  lifecycle {
    ignore_changes = [configuration]
  }
}

# IAM role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "macos-instance-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AmazonSSMManagedInstanceCore policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create an instance profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "macos-instance-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# Launch Template for macOS instances
resource "aws_launch_template" "macos_template" {
  name_prefix = "macos-launch-template-"
  description = "Launch template for macOS EC2 instances"

  # Use the specified macOS AMI
  image_id      = var.macos_ami_id
  instance_type = "mac2-m2.metal"
  key_name      = var.enable_ssh ? aws_key_pair.macos_key[0].key_name : null

  # Add IAM instance profile for SSM
  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_instance_profile.name
  }

  # Specify the host resource group
  placement {
    host_resource_group_arn = aws_resourcegroups_group.aws_resourcegroups_licence_group.arn
    tenancy                 = "host"
  }

  # License specification
  license_specification {
    license_configuration_arn = aws_licensemanager_license_configuration.license_config.arn
  }

  # Network configuration
  vpc_security_group_ids = [aws_security_group.macos_sg.id]

  # User data with Terraform logic for conditional script inclusion
  user_data = base64encode(join("\n", concat(
    # Header script
    [file("${path.module}/user_data/header.sh")],

    # Conditionally include SSM agent script
    var.enable_ssm ? [templatefile("${path.module}/user_data/ssm_agent.sh", {
      ssm_run_as_user = var.ssm_run_as_user
    })] : ["# SSM agent installation skipped"],

    # Footer script
    [file("${path.module}/user_data/footer.sh")]
  )))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = var.instance_name
      Environment = "production"
      OS          = "macOS"
    }
  }

  tags = {
    Name = "macOS Launch Template"
  }
}

# Security Group for macOS instances
resource "aws_security_group" "macos_sg" {
  name_prefix = "macos-security-group-"
  description = "Security group for macOS EC2 instances"

  # SSH access (if enabled)
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = local.ssh_cidr_blocks # Uses both auto-detected IPs and any additional IPs
    }
  }


  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "macOS Security Group"
  }
}

# EC2 Instance using the launch template
resource "aws_instance" "macos_instance" {
  launch_template {
    id      = aws_launch_template.macos_template.id
    version = "$Latest"
  }

  availability_zone = var.availability_zone

  # Dedicated host tenancy configuration
  placement_group = null
  tenancy         = "host"

  tags = {
    Name        = var.instance_name
    Environment = "production"
    ManagedBy   = "terraform"
  }

  # Lifecycle management
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [user_data]
  }
}

# Outputs for verification
output "detected_public_ip" {
  description = "Your detected public IP address"
  value       = local.my_public_ip
}

output "allowed_ssh_cidr_blocks" {
  description = "All CIDR blocks allowed for SSH access"
  value       = var.enable_ssh ? local.ssh_cidr_blocks : []
}

output "ssh_access_status" {
  description = "Status of SSH access"
  value       = var.enable_ssh ? "SSH access is enabled" : "SSH access is disabled"
}

output "emergency_access_enabled" {
  description = "Warning if emergency access from anywhere is enabled"
  value       = var.allow_ssh_from_anywhere && var.enable_ssh ? "⚠️ WARNING: SSH access from anywhere (0.0.0.0/0) is currently enabled! This should only be used temporarily." : "✅ Emergency access is disabled (secure configuration)"
}

output "ssh_connection_command" {
  description = "Command to connect to the instance using SSH"
  value       = var.enable_ssh ? "ssh -i macos-instance-key.pem ec2-user@${aws_instance.macos_instance.public_ip}" : "SSH access is disabled"
}

output "ssm_connection_command" {
  description = "Command to connect to the instance using SSM Session Manager"
  value       = var.enable_ssm ? "aws ssm start-session --target ${aws_instance.macos_instance.id}" : "SSM access is disabled"
}

output "access_methods" {
  description = "Available access methods for the instance"
  value = {
    ssh_enabled = var.enable_ssh
    ssm_enabled = var.enable_ssm
    ssh_user    = "ec2-user"
    ssm_user    = var.ssm_run_as_user
  }
}
