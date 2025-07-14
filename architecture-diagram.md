# AWS macOS EC2 Infrastructure Architecture

## Component Overview

```
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                           AWS License Manager                                   │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │  License Configuration: "MyRequiredLicense"                                     │
    │  • License Count: 32 cores                                                      │
    │  • Counting Type: Core-based                                                    │
    │  • Hard Limit: false                                                            │
    └─────────────────────────────────────────────────────────────────────────────────┘
                                            │
                                            │ provides license tracking
                                            ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                        Host Resource Group                                      │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │  "LicenceManagerResourceGroup"                                                  │
    │                                                                                 │
    │  EC2 Host Management Configuration:                                             │
    │  • Auto-allocate dedicated hosts: YES                                           │
    │  • Auto-release hosts: YES                                                      │
    │  • Auto-recovery: YES                                                           │
    │  • Allowed families: mac2, mac2-m2, mac2-m2pro, mac2-m1ultra                    │
    │                                                                                 │
    │  Resource Protection:                                                           │
    │  • Deletion protection: UNLESS_EMPTY                                            │
    │  • Resource types: AWS::EC2::Host                                               │
    └─────────────────────────────────────────────────────────────────────────────────┘
                                            │
                                            │ manages dedicated hosts
                                            ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                          Launch Template                                        │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │  "mac-launch-template-*"                                                        │
    │  • AMI: ami-0df00719b6554900a (macOS Sequoia)                                   │
    │  • Instance Type: mac2-m2.metal                                                 │
    │  • Tenancy: host (dedicated)                                                    │
    │  • Host Resource Group: ↑ linked                                                │
    │  • License Config: ↑ linked                                                     │
    └─────────────────────────────────────────────────────────────────────────────────┘
                                            │
                                            │ launches instance
                                            ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                           EC2 Mac Instance                                      │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │  "mac-instance" (i-xxxxxxxxx)                                                   │
    │  • Zone: ap-southeast-2a                                                        │
    │  • Tenancy: host                                                                │
    │  • OS: macOS Sequoia 15.1                                                       │
    │  • Hardware: Apple M2 Metal                                                     │
    └─────────────────────────────────────────────────────────────────────────────────┘
```

## Security & Access Components

```
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                            Security Group                                       │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │  "mac-security-group-*"                                                         │
    │                                                                                 │
    │  Inbound Rules (Conditional):                                                   │
    │  • SSH (22): Your IP only → SSH Access (if enabled)                             │
    │  • VNC (5900): Your IP only → Remote Desktop                                    │
    │                                                                                 │
    │  Outbound Rules:                                                                │
    │  • All traffic: 0.0.0.0/0 → Internet Access & SSM Connectivity                  │
    └─────────────────────────────────────────────────────────────────────────────────┘
                                            │
                                            │ secures access
                                            ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                              SSH Key Pair                                       │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │  Generated by Terraform                                                         │
    │  • Algorithm: RSA 4096-bit                                                      │
    │  • Private Key: mac-instance-key.pem (local file)                               │
    │  • Public Key: stored in AWS                                                    │
    │  • Permissions: 0600                                                            │
    └─────────────────────────────────────────────────────────────────────────────────┘
                                            │
                                            │ alternative access method
                                            ▼
    ┌─────────────────────────────────────────────────────────────────────────────────┐
    │                         AWS Systems Manager (SSM)                               │
    ├─────────────────────────────────────────────────────────────────────────────────┤
    │  • IAM Role: mac-instance-ssm-role                                              │
    │  • Policy: AmazonSSMManagedInstanceCore                                         │
    │  • Architecture-aware Agent: Auto-detects ARM64/AMD64                           │
    │  • Run As User: Configurable (default: ec2-user)                                │
    │  • Connection: aws ssm start-session --target instance-id                       │
    └─────────────────────────────────────────────────────────────────────────────────┘
```

## Key Relationships & Data Flow

### 1. License Management Flow
```
License Configuration → Host Resource Group → Launch Template → EC2 Instance
```
- **License Manager** tracks core usage across dedicated hosts
- **Host Resource Group** automatically manages host lifecycle
- **Launch Template** enforces license requirements
- **EC2 Instance** consumes licensed cores

### 2. Host Management Automation
```
Instance Request → Auto-allocate Host → Place Instance → Auto-release (when done)
```
- Eliminates manual dedicated host management
- Automatic cost optimization through host release
- Built-in recovery for host failures

### 3. Flexible Access Methods
```
                     ┌─→ SSH Key → Security Group → SSH Access (if enabled)
Instance Access ─────┤
                     └─→ IAM Role → SSM Agent → Session Manager (if enabled)
```
- **Secure by Default**: Both SSH and SSM access disabled by default
- **IP Restriction**: SSH access limited to your current IP address
- **Architecture-aware**: SSM agent installation detects ARM64 vs AMD64
- **User Customization**: Configure which user SSM sessions run as

## Cost Optimization Features

| Feature | Benefit |
|---------|---------|
| **Auto-allocate Host** | Only provisions hosts when needed |
| **Auto-release Host** | Releases hosts when instances terminate |
| **License Tracking** | Prevents over-provisioning of licensed resources |
| **Host Recovery** | Automatic failover reduces downtime costs |

## Compliance & Governance

- **License Compliance**: Automatic tracking prevents license violations
- **Resource Tagging**: All resources tagged for cost allocation
- **Deletion Protection**: Prevents accidental resource group deletion
- **Lifecycle Management**: Controlled instance creation/destruction
- **Principle of Least Privilege**: SSH and SSM disabled by default
- **Network Security**: IP-restricted access when SSH is enabled
- **Access Flexibility**: Choose between SSH, SSM, or both access methods
