# terraform-aws-macos-instance

Terraform module for provisioning macOS EC2 instances on AWS with flexible access methods.

## Features

- **Architecture-aware SSM Agent**: Automatically detects and installs the appropriate SSM agent for ARM64 or AMD64
- **Flexible Access Methods**: Configure SSH and/or SSM access based on your security requirements
- **IP-based Access Control**: Automatically detects your public IP for secure SSH access
- **Optimized Lifecycle Management**: Fast Terraform operations with configurable timeouts
- **Dedicated Host Management**: Automatic allocation and release of dedicated hosts

## Usage

```hcl
module "macos_instance" {
  source = "github.com/your-org/terraform-aws-macos-instance"

  # Required parameters
  aws_region       = "ap-southeast-2"
  availability_zone = "ap-southeast-2a"

  # Optional parameters with defaults
  instance_name    = "macos-instance"
  macos_ami_id     = "ami-xxxxxxxxxxxxxxxxx"  # Replace with your macOS AMI ID

  # Access configuration (both disabled by default)
  enable_ssh       = true
  enable_ssm       = true
  ssm_run_as_user  = "ec2-user"

  # Additional SSH security options
  additional_ssh_cidr_blocks = ["192.168.1.0/24"]
  allow_ssh_from_anywhere    = false  # Set to true only for testing
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## Security Considerations

- SSH and SSM access are disabled by default for maximum security
- At least one access method must be enabled
- SSH access is restricted to your current public IP by default
- Emergency SSH access from anywhere (0.0.0.0/0) should only be used temporarily

## License

This module is licensed under the MIT License - see the LICENSE file for details.
