# Three-Tier Architecture on AWS with Terraform

This project provisions a production-grade three-tier architecture on AWS using Terraform as the Infrastructure as Code (IaC) tool. It deploys a fully segmented network with web, application, and database tiers across two availability zones, with EC2 instances to validate connectivity across all tiers.

---

## Architecture Overview

```
                        Internet
                           │
                    ┌──────▼──────┐
                    │  Internet   │
                    │   Gateway   │
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │        Public RT        │
              └──────┬──────────┬───────┘
                     │          │
          ┌──────────▼──┐  ┌────▼────────┐
          │Web-Public-A │  │Web-Public-B │
          │ (us-east-1a)│  │(us-east-1b) │
          │Bastion Host │  │  Web VM     │
          └──────┬───── ┘  └─────────────┘
                 │
          ┌──────▼──────┐
          │  NAT Gateway│
          └──────┬───────┘
                 │
       ┌─────────▼──────────┐
       │     Private RT      │
       └──┬──────────────┬───┘
          │              │
  ┌───────▼──────┐  ┌────▼──────────┐
  │App-Private-A │  │  DB-Private-A │
  │ (us-east-1a) │  │ (us-east-1a)  │
  │   App VM     │  │    DB VM      │
  └──────────────┘  └───────────────┘
```

### Tiers

| Tier | Subnets | Visibility | Instances |
|------|---------|------------|-----------|
| Web | Web-Public-A, Web-Public-B | Public | Bastion Host, Web VM |
| Application | App-Private-A, App-Private-B | Private | App VM |
| Database | DB-Private-A, DB-Private-B | Private | DB VM |

---

## Infrastructure Components

### Networking
- **VPC** — `10.0.0.0/16`
- **6 Subnets** across two availability zones (`us-east-1a`, `us-east-1b`):

| Subnet | CIDR | Type | AZ |
|--------|------|------|----|
| Web-Public-A | `10.0.1.0/24` | Public | us-east-1a |
| Web-Public-B | `10.0.2.0/24` | Public | us-east-1b |
| App-Private-A | `10.0.11.0/24` | Private | us-east-1a |
| App-Private-B | `10.0.12.0/24` | Private | us-east-1b |
| DB-Private-A | `10.0.21.0/24` | Private | us-east-1a |
| DB-Private-B | `10.0.22.0/24` | Private | us-east-1b |

- **Internet Gateway** — attached to the VPC for public subnet internet access
- **NAT Gateway** — deployed in Web-Public-A with an Elastic IP, enabling outbound internet access for private subnets
- **Elastic IPs** — two EIPs provisioned (`ThreeTier-eip-A` used by the NAT Gateway)
- **Route Tables**:
  - `Public-RT` — routes `0.0.0.0/0` to the Internet Gateway; associated with both public subnets
  - `Private-RT` — routes `0.0.0.0/0` to the NAT Gateway; associated with all four private subnets

### Security Groups

| Security Group | Inbound Rules | Source |
|----------------|---------------|--------|
| Web-SG | SSH (22), HTTP (80), ICMP | `0.0.0.0/0` |
| App-SG | SSH (22), App port (8080), ICMP | Web-SG |
| DB-SG | SSH (22), MySQL (3306), ICMP | App-SG |

All security groups allow all outbound traffic (`0.0.0.0/0`).

### EC2 Instances

| Instance | AMI | Type | Subnet | Security Group |
|----------|-----|------|--------|----------------|
| Bastion-server | Ubuntu 22.04 | t3.micro | Web-Public-A | Web-SG |
| Web-VM | Ubuntu 22.04 | t3.micro | Web-Public-B | Web-SG |
| App-VM | Ubuntu 22.04 | t3.micro | App-Private-A | App-SG |
| DB-VM | Ubuntu 22.04 | t3.micro | DB-Private-A | DB-SG |

---

## Project Structure

```
terraform-three-tier-architecture/
├── main.tf           # Core infrastructure resources
├── providers.tf      # AWS provider and Terraform version configuration
├── variables.tf      # Input variable declarations
├── terraform.tfvars  # Variable values
├── output.tf         # Output values (IP addresses)
└── README.md
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with appropriate credentials
- An existing AWS EC2 Key Pair in the `us-east-1` region

---

## Usage

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/terraform-three-tier-architecture.git
cd terraform-three-tier-architecture
```

### 2. Set your key pair name

Update `terraform.tfvars` with your EC2 key pair name:

```hcl
key_name = "your-keypair-name"
```

### 3. Initialise Terraform

```bash
terraform init
```

### 4. Review the execution plan

```bash
terraform plan
```

### 5. Apply the configuration

```bash
terraform apply
```

Type `yes` when prompted. Once complete, Terraform will output the IP addresses of all provisioned instances.

### 6. Destroy the infrastructure

```bash
terraform destroy
```

---

## Outputs

| Output | Description |
|--------|-------------|
| `Bastion-server_ip` | Public IP of the Bastion Host |
| `Web-VM_ip` | Public IP of the Web VM |
| `App-VM_ip` | Private IP of the App VM |
| `DB-VM_ip` | Private IP of the DB VM |

---

## Variables

| Variable | Type | Description |
|----------|------|-------------|
| `key_name` | `string` | Name of the EC2 Key Pair used for SSH access |

---

## Provider Configuration

| Setting | Value |
|---------|-------|
| Provider | `hashicorp/aws` |
| Version | `6.38.0` |
| Region | `us-east-1` |

---

## Connectivity Flow

```
Your Machine
    │
    │ SSH (port 22)
    ▼
Bastion Host (Web-Public-A) ──SSH──► App VM (App-Private-A) ──SSH──► DB VM (DB-Private-A)
                                                │
                                           App port 8080
                                                │
                                           Web VM (Web-Public-B)
```

- Access the **Bastion Host** and **Web VM** directly via their public IPs
- SSH into the **App VM** and **DB VM** by tunnelling through the Bastion Host
- The **App VM** is reachable from the Web tier on port `8080`
- The **DB VM** is reachable from the App tier on port `3306` (MySQL)

---

## Security Considerations

- The Bastion Host is the only entry point for SSH access into private instances
- App and DB security groups restrict inbound traffic to the preceding tier only, following the principle of least privilege
- Private instances have no public IPs and rely on the NAT Gateway for outbound-only internet access
- All ICMP traffic is permitted within each tier to support connectivity testing (ping)
