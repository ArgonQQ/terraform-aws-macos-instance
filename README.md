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
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.ssm_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ssm_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ssm_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.macos_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_key_pair.macos_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_launch_template.macos_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_licensemanager_license_configuration.license_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/licensemanager_license_configuration) | resource |
| [aws_resourcegroups_group.aws_resourcegroups_licence_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/resourcegroups_group) | resource |
| [aws_security_group.macos_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [tls_private_key.macos_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [http_http.my_public_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_ssh_cidr_blocks"></a> [additional\_ssh\_cidr\_blocks](#input\_additional\_ssh\_cidr\_blocks) | Additional CIDR blocks to allow SSH access from (in case auto-detection fails) | `list(string)` | `[]` | no |
| <a name="input_allow_ssh_from_anywhere"></a> [allow\_ssh\_from\_anywhere](#input\_allow\_ssh\_from\_anywhere) | If true, allows SSH access from any IP address (0.0.0.0/0) - use only temporarily in emergencies | `bool` | `false` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Availability zone for dedicated hosts | `string` | `"ap-southeast-2a"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"ap-southeast-2"` | no |
| <a name="input_enable_ssh"></a> [enable\_ssh](#input\_enable\_ssh) | Whether to enable SSH access to the instance | `bool` | `false` | no |
| <a name="input_enable_ssm"></a> [enable\_ssm](#input\_enable\_ssm) | Whether to enable SSM access to the instance | `bool` | `true` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name tag for the EC2 instance | `string` | `"macos-instance"` | no |
| <a name="input_macos_ami_id"></a> [macos\_ami\_id](#input\_macos\_ami\_id) | AMI ID for macOS instance (e.g., macOS Sequoia) | `string` | `""` | no |
| <a name="input_ssm_run_as_user"></a> [ssm\_run\_as\_user](#input\_ssm\_run\_as\_user) | User that SSM should run as | `string` | `"ec2-user"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_methods"></a> [access\_methods](#output\_access\_methods) | Available access methods for the instance |
| <a name="output_allowed_ssh_cidr_blocks"></a> [allowed\_ssh\_cidr\_blocks](#output\_allowed\_ssh\_cidr\_blocks) | All CIDR blocks allowed for SSH access |
| <a name="output_detected_public_ip"></a> [detected\_public\_ip](#output\_detected\_public\_ip) | Your detected public IP address |
| <a name="output_emergency_access_enabled"></a> [emergency\_access\_enabled](#output\_emergency\_access\_enabled) | Warning if emergency access from anywhere is enabled |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the Mac EC2 instance |
| <a name="output_instance_private_ip"></a> [instance\_private\_ip](#output\_instance\_private\_ip) | Private IP address of the Mac instance |
| <a name="output_instance_public_ip"></a> [instance\_public\_ip](#output\_instance\_public\_ip) | Public IP address of the Mac instance |
| <a name="output_launch_template_arn"></a> [launch\_template\_arn](#output\_launch\_template\_arn) | ARN of the launch template |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group |
| <a name="output_ssh_access_status"></a> [ssh\_access\_status](#output\_ssh\_access\_status) | Status of SSH access |
| <a name="output_ssh_connection_command"></a> [ssh\_connection\_command](#output\_ssh\_connection\_command) | Command to connect to the instance using SSH |
| <a name="output_ssm_connection_command"></a> [ssm\_connection\_command](#output\_ssm\_connection\_command) | Command to connect to the instance using SSM Session Manager |
<!-- END_TF_DOCS -->

## Security Considerations

- SSH and SSM access are disabled by default for maximum security
- At least one access method must be enabled
- SSH access is restricted to your current public IP by default
- Emergency SSH access from anywhere (0.0.0.0/0) should only be used temporarily

## License

This module is licensed under the MIT License - see the LICENSE file for details.
