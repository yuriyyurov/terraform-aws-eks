# Network Configuration Requirements for Jambonz SIP/RTP Nodes

> **Document for Infrastructure Engineer**  
> Describes AWS EKS network configuration requirements for Jambonz SIP/RTP nodes

## Node Requirements

### Why Elastic IP (Public IP) is Required

Jambonz uses two DaemonSets with `hostNetwork: true`:

| DaemonSet | Purpose | Protocols |
|-----------|---------|-----------|
| `jambonz-sbc-sip` | SIP signaling | UDP/TCP 5060 |
| `jambonz-sbc-rtp` | RTP media (rtpengine) | UDP 10000-60000 |

**Reasons why Public IP is required:**

1. **SIP protocol embeds IP addresses in message headers** (Via, Contact, SDP). When behind NAT, the external provider sees a private IP and cannot send responses back.

2. **RTP requires a wide range of UDP ports** (10000-60000). NAT Gateway does not support static port forwarding for such a large range.

3. **Symmetric NAT (AWS NAT Gateway)** changes the source port for each connection, which breaks SIP/RTP communication.

> **Important:** NAT Gateway is **NOT suitable** for SIP/RTP traffic. Use Public Subnet with Elastic IP.

---

## Node Pool Configuration

```yaml
Node Pool: voip-edge
  Instance Type: c5.xlarge (or equivalent)
  Subnet: Public Subnet
  Assign Public IP: Yes (Elastic IP)
  Labels:
    - voip-environment: sip   # for SIP node
    - voip-environment: rtp   # for RTP node
```

### Instance Requirements

- **SIP Node**: minimum 2 vCPU, 4GB RAM
- **RTP Node**: minimum 4 vCPU, 8GB RAM (for media processing)
- Enhanced Networking recommended for low latency

---

## Security Groups

### SG for SIP Node (`sg-jambonz-sip`)

| Direction | Protocol | Port | Source | Description |
|-----------|----------|------|--------|-------------|
| Inbound | UDP | 5060 | SIP Provider CIDR | SIP signaling |
| Inbound | TCP | 5060 | SIP Provider CIDR | SIP over TCP |
| Inbound | TCP | 5061 | SIP Provider CIDR | SIP over TLS (optional) |
| Inbound | TCP | 9022 | VPC CIDR | drachtio admin (internal only) |
| Outbound | All | All | 0.0.0.0/0 | Outbound calls |

**Example SIP Provider CIDR (Twilio):**
- `54.172.60.0/30`
- `54.244.51.0/30`
- (full list: https://www.twilio.com/docs/sip-trunking/ip-addresses)

### SG for RTP Node (`sg-jambonz-rtp`)

| Direction | Protocol | Port | Source | Description |
|-----------|----------|------|--------|-------------|
| Inbound | UDP | 10000-60000 | 0.0.0.0/0 | RTP media streams |
| Inbound | TCP | 22222 | VPC CIDR | rtpengine NG control (internal) |
| Inbound | UDP | 22223 | VPC CIDR | rtpengine sidecar (internal) |
| Outbound | All | All | 0.0.0.0/0 | Return RTP traffic |

> **Note:** RTP source IP may differ from SIP provider IP (media relay), therefore inbound `0.0.0.0/0` for RTP ports.

---

## Routing

### Route Table for Public Subnet (VoIP Edge)

| Destination | Target | Description |
|-------------|--------|-------------|
| 10.0.0.0/16 | local | VPC internal |
| 0.0.0.0/0 | igw-xxx | Internet Gateway |

### Route Table for Private Subnet (other components)

| Destination | Target | Description |
|-------------|--------|-------------|
| 10.0.0.0/16 | local | VPC internal |
| 0.0.0.0/0 | nat-xxx | NAT Gateway |

### Elastic IP Association

```
SIP Node EC2 Instance → EIP (e.g., 1.2.3.4)
RTP Node EC2 Instance → EIP (e.g., 5.6.7.8)
```

---

## Network Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
│                    (SIP Carriers, Users)                        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                    Internet Gateway
                          │
┌─────────────────────────┼───────────────────────────────────────┐
│  VPC 10.0.0.0/16        │                                       │
│                         │                                       │
│  ┌──────────────────────┴──────────────────────────────────┐   │
│  │  Public Subnet 10.0.1.0/24                               │   │
│  │                                                          │   │
│  │  ┌─────────────────┐    ┌─────────────────┐             │   │
│  │  │ SIP Node        │    │ RTP Node        │             │   │
│  │  │ EIP: 1.2.3.4    │    │ EIP: 5.6.7.8    │             │   │
│  │  │ :5060 UDP/TCP   │    │ :10000-60000    │             │   │
│  │  │ SG: sg-sip      │    │ SG: sg-rtp      │             │   │
│  │  │ Label: sip      │    │ Label: rtp      │             │   │
│  │  └─────────────────┘    └─────────────────┘             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                         NAT Gateway                              │
│                              │                                   │
│  ┌───────────────────────────┴──────────────────────────────┐   │
│  │  Private Subnet 10.0.2.0/24                              │   │
│  │                                                          │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│   │
│  │  │Feature      │ │API Server   │ │ MySQL, Redis,       ││   │
│  │  │Server       │ │             │ │ InfluxDB            ││   │
│  │  └─────────────┘ └─────────────┘ └─────────────────────┘│   │
│  │  (Outbound via NAT Gateway)                              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Terraform Example (AWS EKS Node Group)

```hcl
resource "aws_eks_node_group" "voip_sip" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "voip-sip"
  node_role_arn   = aws_iam_role.eks_node.arn
  
  # Public Subnet with Internet Gateway
  subnet_ids = [aws_subnet.public.id]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["c5.xlarge"]

  labels = {
    "voip-environment" = "sip"
  }

  # Important: Public IP for SIP traffic
  launch_template {
    id      = aws_launch_template.voip_sip.id
    version = aws_launch_template.voip_sip.latest_version
  }
}

resource "aws_launch_template" "voip_sip" {
  name = "voip-sip-template"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.jambonz_sip.id]
  }
}

resource "aws_security_group" "jambonz_sip" {
  name        = "sg-jambonz-sip"
  description = "Security group for Jambonz SIP nodes"
  vpc_id      = aws_vpc.main.id

  # SIP UDP
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = var.sip_provider_cidrs
  }

  # SIP TCP
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = var.sip_provider_cidrs
  }

  # drachtio admin (internal)
  ingress {
    from_port   = 9022
    to_port     = 9022
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jambonz_rtp" {
  name        = "sg-jambonz-rtp"
  description = "Security group for Jambonz RTP nodes"
  vpc_id      = aws_vpc.main.id

  # RTP media (wide range)
  ingress {
    from_port   = 10000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # rtpengine NG control (internal)
  ingress {
    from_port   = 22222
    to_port     = 22222
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # rtpengine sidecar (internal)
  ingress {
    from_port   = 22223
    to_port     = 22223
    protocol    = "udp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## Checklist for Infrastructure Engineer

- [ ] Create Public Subnet with route via Internet Gateway
- [ ] Allocate 2 Elastic IPs (for SIP and RTP nodes)
- [ ] Create Security Group `sg-jambonz-sip` with rules above
- [ ] Create Security Group `sg-jambonz-rtp` with rules above
- [ ] Create Node Group in Public Subnet with auto-assign public IP
- [ ] Apply labels `voip-environment: sip` and `voip-environment: rtp`
- [ ] Verify EIP is associated with nodes after launch
- [ ] Test connectivity: `nc -vuz <EIP> 5060` from external host

---

## Related Documentation

- [DEPENDENCIES.md](./DEPENDENCIES.md) - Jambonz architecture and component dependencies
- [.cursorrules](../.cursorrules) - Kubernetes manifests and configuration
