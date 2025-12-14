# Jambonz Platform - Dependencies & Architecture Documentation

> **Last Updated**: December 11, 2025  
> **Source**: Architecture derived from Docker image inspection and official [jambonz GitHub repositories](https://github.com/jambonz). 
> **Note**: The [jambonz/helm-charts](https://github.com/jambonz/helm-charts) repository was **archived on January 16, 2024** and is read-only. Kubernetes deployments require manual manifest creation or using paid support scripts.

## Overview

Jambonz is an open-source, self-hosted CPaaS (Communications Platform as a Service) for building voice AI applications. This document provides the accurate production architecture for AWS EKS deployment.

**Official Resources**:
- Website: https://www.jambonz.org
- GitHub Organization: https://github.com/jambonz
- Helm Charts: https://github.com/jambonz/helm-charts

---

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS EKS Cluster (bonzai namespace)                                    │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                          │
│   ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐ │
│   │                                        External Traffic                                            │ │
│   │                                              │                                                     │ │
│   │         ┌────────────────────────────────────┼────────────────────────────────┐                   │ │
│   │         │                                    │                                │                   │ │
│   │         ▼                                    ▼                                ▼                   │ │
│   │  ┌──────────────┐                    ┌───────────────┐                ┌───────────────┐          │ │
│   │  │  SIP/VoIP    │                    │   HTTP/REST   │                │  Web Browser  │          │ │
│   │  │  Carriers    │                    │   Webhooks    │                │    Users      │          │ │
│   │  │  (5060 UDP)  │                    │               │                │               │          │ │
│   │  └──────┬───────┘                    └───────┬───────┘                └───────┬───────┘          │ │
│   └─────────┼────────────────────────────────────┼────────────────────────────────┼──────────────────┘ │
│             │                                    │                                │                    │
│             ▼                                    │                                ▼                    │
│  ┌──────────────────────────────────┐            │               ┌────────────────────────────────┐   │
│  │   SBC-SIP DaemonSet (Edge Node)  │            │               │       jambonz-webapp           │   │
│  │   hostNetwork: true              │            │               │       (React UI)               │   │
│  │                                  │            │               │       Port: 3001               │   │
│  │  ┌────────────┐ ┌─────────────┐  │            │               └───────────┬────────────────────┘   │
│  │  │  drachtio  │ │ sbc-sip-    │  │            │                           │                        │
│  │  │  (SIP      │ │ sidecar     │  │            │                           ▼                        │
│  │  │  signaling)│ │ (registrar) │  │            │               ┌────────────────────────────────┐   │
│  │  │  Port:5060 │ │             │  │            │               │     jambonz-api-server         │   │
│  │  │  Port:9022 │ │             │  │            │               │     (REST API)                 │   │
│  │  └─────┬──────┘ └─────────────┘  │            │               │     Port: 3000                 │   │
│  │        │        ┌─────────────┐  │            │               └───────────┬────────────────────┘   │
│  │        │        │    smpp     │  │            │                           │                        │
│  │        │        │ (SMS ESME)  │  │            │                           │                        │
│  │        │        └─────────────┘  │            │                           │                        │
│  └────────┼─────────────────────────┘            │                           │                        │
│           │                                      │                           │                        │
│           │ HTTP POST (INVITE routing)           │                           │                        │
│           ▼                                      │                           │                        │
│  ┌────────────────────────────────┐              │                           │                        │
│  │     sbc-call-router            │              │                           │                        │
│  │     (INVITE Router)            │              │                           │                        │
│  │     Port: 3000                 │              │                           │                        │
│  │                                │              │                           │                        │
│  │  Routes based on source IP:    │              │                           │                        │
│  │  - External → sbc-inbound      │              │                           │                        │
│  │  - Internal → sbc-outbound     │              │                           │                        │
│  └─────────┬──────────────────────┘              │                           │                        │
│            │                                     │                           │                        │
│    ┌───────┴───────┐                             │                           │                        │
│    ▼               ▼                             │                           │                        │
│  ┌─────────────┐ ┌─────────────┐                 │                           │                        │
│  │sbc-inbound  │ │sbc-outbound │                 │                           │                        │
│  │(Deployment) │ │(Deployment) │                 │                           │                        │
│  │             │ │             │                 │                           │                        │
│  │Drachtio     │ │Drachtio     │                 │                           │                        │
│  │Outbound     │ │Outbound     │                 │                           │                        │
│  │Port:4000    │ │Port:4000    │                 │                           │                        │
│  └──────┬──────┘ └──────┬──────┘                 │                           │                        │
│         │               │                        │                           │                        │
│         └───────┬───────┘                        │                           │                        │
│                 │                                │                           │                        │
│                 │ K8S_FEATURE_SERVER_SERVICE_NAME│                           │                        │
│                 ▼                                │                           │                        │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐│
│  │                            Feature Server Pod (Core Telephony)                                     ││
│  │                                                                                                    ││
│  │  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐           ││
│  │  │ jambonz-feature-server  │  │     drachtio-server     │  │       freeswitch        │           ││
│  │  │      (Node.js)          │  │    (SIP signaling)      │  │     (Media server)      │           ││
│  │  │                         │  │                         │  │                         │           ││
│  │  │  - Call orchestration   │  │  - SIP protocol         │  │  - TTS/STT integration  │           ││
│  │  │  - Webhook execution    │◄─┤  - B2BUA                │◄─┤  - Audio processing     │           ││
│  │  │  - Application logic    │  │  - Call routing         │  │  - Recording            │           ││
│  │  │  - IVR / LLM / AI       │  │                         │  │  - Conferencing         │           ││
│  │  │                         │  │                         │  │                         │           ││
│  │  │  Port: 3000 (HTTP)      │  │  Port: 9022 (ctrl)      │  │  Port: 8021 (ESL)       │           ││
│  │  │                         │  │  Port: 5060 (SIP)       │  │                         │           ││
│  │  └─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘           ││
│  │                                                                                                    ││
│  │                         localhost (127.0.0.1) - Sidecar communication                             ││
│  └────────────────────────────────────────────────────────────────────────────────────────────────────┘│
│                 │                                                                                      │
│                 │ K8S_SBC_SIP_SERVICE_NAME (outbound calls)                                           │
│                 ▼                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                        SBC-RTP DaemonSet (RTP Edge Node)                                         │  │
│  │                        hostNetwork: true                                                          │  │
│  │                                                                                                   │  │
│  │  ┌─────────────────────────────────┐  ┌─────────────────────────────────────────┐               │  │
│  │  │       rtpengine-sidecar         │  │              rtpengine                   │               │  │
│  │  │       (Node.js)                 │  │          (Media Proxy)                   │               │  │
│  │  │                                 │  │                                          │               │  │
│  │  │  - DTMF event handler           │  │  - RTP/RTCP media relay                  │               │  │
│  │  │  - Stats collection             │  │  - Codec transcoding                     │               │  │
│  │  │  - Service discovery            │  │  - DTMF detection                        │               │  │
│  │  │                                 │  │  - Recording                             │               │  │
│  │  │  Port: 22223 (DTMF)             │  │  Port: 22222 (NG control)                │               │  │
│  │  │                                 │  │  Ports: 10000-60000 (RTP)                │               │  │
│  │  └─────────────────────────────────┘  └─────────────────────────────────────────┘               │  │
│  │                                                                                                   │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                    Data Layer                                                      │  │
│  │                                                                                                    │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │  │
│  │  │       MySQL         │  │       Redis         │  │     InfluxDB        │  │   PostgreSQL    │  │  │
│  │  │   (Persistent)      │  │   (Real-time)       │  │   (Time Series)     │  │   (Grafana)     │  │  │
│  │  │                     │  │                     │  │                     │  │                 │  │  │
│  │  │  - Accounts         │  │  - Sessions         │  │  - CDRs             │  │  - Grafana DB   │  │  │
│  │  │  - Applications     │  │  - Call state       │  │  - Alerts           │  │  - Dashboards   │  │  │
│  │  │  - Carriers         │  │  - Service disc.    │  │  - Metrics          │  │                 │  │  │
│  │  │  - Phone numbers    │  │  - Registrations    │  │  - Call counts      │  │                 │  │  │
│  │  │                     │  │  - RTP endpoints    │  │                     │  │                 │  │  │
│  │  │  Port: 3306         │  │  Port: 6379         │  │  Port: 8086         │  │  Port: 5432     │  │  │
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │  │
│  │                                                                                                    │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                   Monitoring Stack (Optional)                                      │  │
│  │                                                                                                    │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │  │
│  │  │     Homer           │  │      Jaeger         │  │     Telegraf        │  │    Grafana      │  │  │
│  │  │   (SIP Capture)     │  │   (Tracing)         │  │   (Metrics)         │  │  (Dashboards)   │  │  │
│  │  │  Port: 9080         │  │  Port: 16686        │  │  Port: 8125         │  │  Port: 3000     │  │  │
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │  │
│  │                                                                                                    │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. SBC-SIP DaemonSet

**Purpose**: Edge-facing SIP signaling layer that receives all external SIP traffic. Runs on dedicated nodes with `hostNetwork: true`.

| Property | Value |
|----------|-------|
| K8S Type | DaemonSet |
| Pod Name | `jambonz-sbc-sip` |
| Node Selector | `voip-environment: sip` |
| Host Network | `true` |

**Containers in Pod**:

| Container | Image | Purpose | Port |
|-----------|-------|---------|------|
| drachtio | `drachtio/drachtio-server:latest` (v0.9.4-rc2) | SIP signaling server | 5060 (SIP), 9022 (control) |
| sbc-sip-sidecar | `jambonz/sbc-sip-sidecar:latest` (0.9.5) | Handles REGISTER, registrar, OPTIONS | - |
| smpp | `jambonz/smpp-esme:latest` (0.9.5) | SMS gateway | 80 |

**INVITE Routing**: Drachtio is configured to POST incoming INVITEs to `sbc-call-router:3000` for routing decisions.

**sbc-sip-sidecar Environment Variables**:
```yaml
DRACHTIO_HOST: "127.0.0.1"                         # Localhost (same pod as drachtio)
DRACHTIO_PORT: "9022"
DRACHTIO_SECRET: <secret>

# Database connections (use full FQDN)
JAMBONES_MYSQL_HOST: "mysql.bonzai.svc.cluster.local"
JAMBONES_MYSQL_USER: jambones
JAMBONES_MYSQL_PASSWORD: <secret>
JAMBONES_MYSQL_DATABASE: jambones
JAMBONES_REDIS_HOST: "redis.bonzai.svc.cluster.local"
JAMBONES_TIME_SERIES_HOST: "influxdb.bonzai.svc.cluster.local"

JAMBONES_SBCS: "sbc-sip.bonzai.svc.cluster.local"
JAMBONES_NETWORK_CIDR: "172.31.0.0/16"
```

**Dependencies**:
- MySQL (required) - Account/carrier lookup
- Redis (required) - Registration storage, service discovery
- InfluxDB (required) - Alerts, metrics

---

### 2. SBC-RTP DaemonSet

**Purpose**: Media handling layer (RTP). Runs on dedicated nodes with `hostNetwork: true` for direct RTP traffic.

> **IMPORTANT**: RTPEngine is an **independent deployment**, NOT a sidecar to sbc-inbound/sbc-outbound. It runs on separate edge nodes for performance.

| Property | Value |
|----------|-------|
| K8S Type | DaemonSet (or StatefulSet for recordings) |
| Pod Name | `jambonz-sbc-rtp` |
| Node Selector | `voip-environment: rtp` |
| Host Network | `true` |

**Containers in Pod**:

| Container | Image | Purpose | Port |
|-----------|-------|---------|------|
| rtpengine | `jambonz/rtpengine:latest` (v11.5.1.31) | RTP media proxy, transcoding, recording | 22222 (NG), 10000-60000 (RTP) |
| rtpengine-sidecar | `jambonz/rtpengine-sidecar:latest` (0.9.5) | DTMF events, stats, service discovery | 22223 |

**Discovery**: sbc-inbound and sbc-outbound discover rtpengine via DNS lookup of `K8S_RTPENGINE_SERVICE_NAME`.

---

### 3. sbc-call-router (Deployment)

**Purpose**: Simple HTTP service that routes incoming INVITEs to either sbc-inbound or sbc-outbound based on source IP.

| Property | Value |
|----------|-------|
| K8S Type | Deployment |
| Service Name | `sbc-call-router` |
| HTTP Port | `3000` |
| Docker Image | `jambonz/sbc-call-router:latest` (0.9.5) |

**Routing Logic**:
- **Non-K8S Mode**: Source IP in private CIDR → Route to `sbc-outbound`; External IP → Route to `sbc-inbound`
- **K8S Mode**: Uses `X-Jambonz-Routing` header in the INVITE body to distinguish outbound vs inbound calls

**Key Environment Variables**:
```yaml
# Required
K8S: "1"                                          # Enables K8S routing mode
JAMBONES_NETWORK_CIDR: "172.31.0.0/16"           # Required if K8S not set

# K8S Service Discovery (use full FQDN)
K8S_SBC_INBOUND_SERVICE_NAME: "sbc-inbound.bonzai.svc.cluster.local:4000"
K8S_SBC_OUTBOUND_SERVICE_NAME: "sbc-outbound.bonzai.svc.cluster.local:4000"
K8S_SBC_REGISTER_SERVICE_NAME: "sbc-sip-sidecar.bonzai.svc.cluster.local"
K8S_SBC_OPTIONS_SERVICE_NAME: "sbc-sip-sidecar.bonzai.svc.cluster.local"

# Alternative: Tagged routing (new in 0.9.x)
# JAMBONZ_TAGGED_INBOUND: "1"                     # Use tagged routing instead of URI routing
```

---

### 4. sbc-inbound (Deployment)

**Purpose**: Handles inbound calls from SIP carriers and registered devices.

| Property | Value |
|----------|-------|
| K8S Type | Deployment |
| Service Name | `sbc-inbound` |
| Drachtio Port | `4000` (outbound mode) |
| HTTP Port | `3000` (health) |
| Docker Image | `jambonz/sbc-inbound:latest` (0.9.5) |
| Node.js | `>= 20.0.0` |

**Key Functions**:
- Authenticates SIP devices via webhook callback
- Validates carrier credentials
- Routes to feature server for call processing

**Key Environment Variables**:
```yaml
K8S: "1"
DRACHTIO_PORT: "4000"                             # Listens for drachtio outbound connections
DRACHTIO_SECRET: <secret>

# Feature Server Discovery (use full FQDN)
K8S_FEATURE_SERVER_SERVICE_NAME: "jambonz-feature-server.bonzai.svc.cluster.local"

# RTPEngine Discovery (use full FQDN)
K8S_RTPENGINE_SERVICE_NAME: "rtpengine-ng.bonzai.svc.cluster.local:22222"

# Optional: Feature server transport
K8S_FEATURE_SERVER_TRANSPORT: tcp                 # Use TCP instead of HTTP

# Database connections (use full FQDN)
JAMBONES_MYSQL_HOST: "mysql.bonzai.svc.cluster.local"
JAMBONES_REDIS_HOST: "redis.bonzai.svc.cluster.local"
JAMBONES_TIME_SERIES_HOST: "influxdb.bonzai.svc.cluster.local"
```

---

### 5. sbc-outbound (Deployment)

**Purpose**: Handles outbound calls to SIP carriers and registered devices.

| Property | Value |
|----------|-------|
| K8S Type | Deployment |
| Service Name | `sbc-outbound` |
| Drachtio Port | `4000` (outbound mode) |
| HTTP Port | `3000` (health) |
| Docker Image | `jambonz/sbc-outbound:latest` (0.9.5) |
| Node.js | `>= 18.0.0` |

**Key Environment Variables**:
```yaml
K8S: "1"
DRACHTIO_PORT: "4000"                             # Listens for drachtio outbound connections
DRACHTIO_SECRET: <secret>

# RTPEngine Discovery (use full FQDN)
K8S_RTPENGINE_SERVICE_NAME: "rtpengine-ng.bonzai.svc.cluster.local:22222"

# Database connections (use full FQDN)
JAMBONES_MYSQL_HOST: "mysql.bonzai.svc.cluster.local"
JAMBONES_REDIS_HOST: "redis.bonzai.svc.cluster.local"
JAMBONES_TIME_SERIES_HOST: "influxdb.bonzai.svc.cluster.local"
```

---

### 6. Feature Server (Deployment)

**Purpose**: Core telephony orchestration. Executes webhook applications, handles IVR, integrates with AI/LLM services.

| Property | Value |
|----------|-------|
| K8S Type | Deployment |
| Service Name | `feature-server` |
| HTTP Port | `3000` |
| Docker Image | `jambonz/feature-server:latest` (0.9.5) |
| Node.js | `>= 18.x` |

**Sidecars** (same pod, localhost communication):

| Container | Image | Purpose | Port |
|-----------|-------|---------|------|
| drachtio | `drachtio/drachtio-server:latest` (v0.9.4-rc2) | SIP signaling (B2BUA) | 9022 (control), 5060 (SIP) |
| freeswitch | `drachtio/drachtio-freeswitch-mrf:latest` (FreeSWITCH 1.10.10) | Media server (TTS/STT/audio) | 8021 (ESL) |

**Supported AI/LLM Features** (as of 0.9.5):
- Speech-to-Text (STT): AWS Transcribe, Google, Microsoft, Deepgram, Soniox, Gladia
- Text-to-Speech (TTS): AWS Polly, Google, Microsoft, ElevenLabs
- LLM Integration: OpenAI, Anthropic, Google Gemini (including speech-to-speech), custom webhooks
- MCP (Model Context Protocol) Client Support: Connect to MCP servers from LLM verb
- IVR: DTMF gathering, menu navigation
- Recording: Call recording to cloud storage (S3, GCS, Azure Blob)

**Key Environment Variables**:
```yaml
K8S: "1"

# SBC Discovery (use full FQDN)
K8S_SBC_SIP_SERVICE_NAME: "sbc-sip.bonzai.svc.cluster.local"

# Drachtio Sidecar (localhost - same pod)
DRACHTIO_HOST: "127.0.0.1"
DRACHTIO_PORT: "9022"
DRACHTIO_SECRET: <secret>

# Freeswitch Sidecar (localhost - same pod)
JAMBONES_FREESWITCH: "127.0.0.1:8021:<secret>"    # Format: host:port:password

# Database connections (use full FQDN)
JAMBONES_MYSQL_HOST: "mysql.bonzai.svc.cluster.local"
JAMBONES_MYSQL_USER: jambones
JAMBONES_MYSQL_PASSWORD: <secret>
JAMBONES_MYSQL_DATABASE: jambones
JAMBONES_REDIS_HOST: "redis.bonzai.svc.cluster.local"
JAMBONES_REDIS_PORT: "6379"
JAMBONES_TIME_SERIES_HOST: "influxdb.bonzai.svc.cluster.local"

# Network
JAMBONES_NETWORK_CIDR: "172.31.0.0/16"            # Required if K8S not set

# Optional: Application Settings
HTTP_PORT: "3000"
JAMBONES_LOGLEVEL: info
ENCRYPTION_SECRET: <secret>                        # For encrypting credentials
```

---

### 7. jambonz-api-server (Deployment)

**Purpose**: REST API for provisioning accounts, applications, carriers, phone numbers.

| Property | Value |
|----------|-------|
| K8S Type | Deployment |
| Service Name | `api-server` |
| HTTP Port | `3000` |
| Docker Image | `jambonz/api-server:latest` (0.9.5) |
| Node.js | `>= 18.x` |

**Key Functions**:
- Account management
- Application configuration (webhooks)
- Application environment variables (new in 0.9.x)
- Carrier/SIP trunk management
- Phone number assignment
- CDR queries
- Create-call API (connects to feature server)
- Speech vendor credential management

**Key Environment Variables**:
```yaml
K8S: "1"
K8S_FEATURE_SERVER_SERVICE_NAME: "jambonz-feature-server.bonzai.svc.cluster.local"
K8S_FEATURE_SERVER_SERVICE_PORT: "3000"           # Optional, defaults to 3000

# Database connections (use full FQDN)
JAMBONES_MYSQL_HOST: "mysql.bonzai.svc.cluster.local"
JAMBONES_MYSQL_USER: jambones
JAMBONES_MYSQL_PASSWORD: <secret>
JAMBONES_MYSQL_DATABASE: jambones
JAMBONES_REDIS_HOST: "redis.bonzai.svc.cluster.local"
JAMBONES_TIME_SERIES_HOST: "influxdb.bonzai.svc.cluster.local"

JWT_SECRET: <secret>                               # For API authentication
ENCRYPTION_SECRET: <secret>                        # For encrypting stored credentials

# Optional: Monitoring integration (use full FQDN)
HOMER_BASE_URL: "http://homer-webapp.bonzai.svc.cluster.local"
JAEGER_BASE_URL: "http://jaeger-query.bonzai.svc.cluster.local:16686"
```

---

### 8. jambonz-webapp (Deployment)

**Purpose**: React-based web UI for administration.

| Property | Value |
|----------|-------|
| K8S Type | Deployment |
| Service Name | `jambonz-webapp` |
| HTTP Port | `3001` |
| Docker Image | `jambonz/webapp:latest` (0.9.5) |
| Node.js | `>= 18` |

**Dependencies**:
- jambonz-api-server (backend API)

**Key Environment Variables**:
```yaml
API_BASE_URL: "http://jambonz-api-server.bonzai.svc.cluster.local:3000"
```

---

## Data Layer Services

### MySQL Database

| Property | Value |
|----------|-------|
| Service Name | `mysql` |
| FQDN | `mysql.bonzai.svc.cluster.local` |
| Port | `3306` |
| Schema | `jambones-sql.sql` |

**Used by**: ALL components

**Key Tables**:
- `accounts` - Service provider accounts
- `applications` - Voice applications
- `voip_carriers` - SIP carrier configurations
- `phone_numbers` - DIDs and routing
- `sip_gateways` - Carrier gateway IPs
- `clients` - Registered SIP devices

---

### Redis

| Property | Value |
|----------|-------|
| Service Name | `redis` |
| FQDN | `redis.bonzai.svc.cluster.local` |
| Port | `6379` |

**Used by**: ALL components

**Key Sets**:
- `{cluster}:active-fs` - Active feature servers
- `{cluster}:active-rtp` - Active RTP engines
- `{cluster}:active-sip` - Active SBC addresses

---

### InfluxDB (Time Series)

| Property | Value |
|----------|-------|
| Service Name | `influxdb` |
| FQDN | `influxdb.bonzai.svc.cluster.local` |
| Port | `8086` |

**Used by**: sbc-inbound, sbc-outbound, sbc-sip-sidecar, api-server

**Purpose**: CDRs, alerts, call metrics, billing data

---

## Kubernetes Services

> **FQDN Format**: Always use `servicename.bonzai.svc.cluster.local` for service connectivity.

| Service Name | FQDN | Type | Ports |
|--------------|------|------|-------|
| `sbc-sip` | `sbc-sip.bonzai.svc.cluster.local` | ClusterIP (headless) | 5060 UDP/TCP |
| `rtpengine-ng` | `rtpengine-ng.bonzai.svc.cluster.local` | ClusterIP (headless) | 22222 TCP |
| `sbc-call-router` | `sbc-call-router.bonzai.svc.cluster.local` | ClusterIP | 3000 |
| `sbc-inbound` | `sbc-inbound.bonzai.svc.cluster.local` | ClusterIP | 4000 |
| `sbc-outbound` | `sbc-outbound.bonzai.svc.cluster.local` | ClusterIP | 4000 |
| `jambonz-feature-server` | `jambonz-feature-server.bonzai.svc.cluster.local` | ClusterIP | 3000 |
| `jambonz-api-server` | `jambonz-api-server.bonzai.svc.cluster.local` | ClusterIP | 3000 |
| `jambonz-webapp` | `jambonz-webapp.bonzai.svc.cluster.local` | ClusterIP | 3001 |
| `mysql` | `mysql.bonzai.svc.cluster.local` | ClusterIP | 3306 |
| `redis` | `redis.bonzai.svc.cluster.local` | ClusterIP | 6379 |
| `influxdb` | `influxdb.bonzai.svc.cluster.local` | ClusterIP | 8086 |

---

## Call Flow

### Inbound Call (Carrier → Application)

```
1. Carrier sends INVITE to SBC public IP:5060
2. drachtio (sbc-sip pod) receives INVITE
3. drachtio POSTs to sbc-call-router:3000 for routing
4. sbc-call-router determines source is external → returns sbc-inbound:4000
5. drachtio forwards to sbc-inbound
6. sbc-inbound:
   - Validates carrier by IP/credentials
   - Looks up application for DID
   - Allocates rtpengine via K8S_RTPENGINE_SERVICE_NAME
   - Forwards to feature-server via K8S_FEATURE_SERVER_SERVICE_NAME
7. feature-server:
   - Fetches application webhook
   - Executes call logic (IVR, TTS, STT, LLM)
   - Routes call as configured
```

### Outbound Call (Application → Carrier)

```
1. feature-server initiates outbound call
2. feature-server sends INVITE to sbc-sip (K8S_SBC_SIP_SERVICE_NAME)
3. drachtio (sbc-sip pod) POSTs to sbc-call-router
4. sbc-call-router determines source is internal → returns sbc-outbound:4000
5. drachtio forwards to sbc-outbound
6. sbc-outbound:
   - Looks up outbound carrier/gateway
   - Allocates rtpengine
   - Sends INVITE to carrier
```

---

## Node Pool Requirements

For production, jambonz requires dedicated node pools:

| Node Pool | Label | Purpose | Host Network |
|-----------|-------|---------|--------------|
| SIP Nodes | `voip-environment: sip` | SBC-SIP DaemonSet | Yes |
| RTP Nodes | `voip-environment: rtp` | SBC-RTP DaemonSet | Yes |
| General | (default) | All other deployments | No |

> **Note**: For cost savings, SIP and RTP can share a single edge node pool, but separate pools are recommended for production.

---

## Environment Variable Reference

### K8S Service Discovery Variables

| Variable | Used By | Value |
|----------|---------|-------|
| `K8S` | All | `"1"` (enables K8S mode) |
| `K8S_FEATURE_SERVER_SERVICE_NAME` | sbc-inbound, api-server | `jambonz-feature-server.bonzai.svc.cluster.local` |
| `K8S_RTPENGINE_SERVICE_NAME` | sbc-inbound, sbc-outbound | `rtpengine-ng.bonzai.svc.cluster.local:22222` |
| `K8S_SBC_SIP_SERVICE_NAME` | feature-server | `sbc-sip.bonzai.svc.cluster.local` |
| `K8S_SBC_INBOUND_SERVICE_NAME` | sbc-call-router | `sbc-inbound.bonzai.svc.cluster.local:4000` |
| `K8S_SBC_OUTBOUND_SERVICE_NAME` | sbc-call-router | `sbc-outbound.bonzai.svc.cluster.local:4000` |

---

## Deployment Order

Based on dependency analysis:

1. **Infrastructure Layer**:
   - MySQL (with jambonz schema)
   - Redis
   - InfluxDB

2. **Feature Server** (core telephony):
   - feature-server deployment

3. **SBC Layer** (edge-facing):
   - sbc-rtp DaemonSet (on RTP nodes)
   - sbc-call-router deployment
   - sbc-inbound deployment
   - sbc-outbound deployment
   - sbc-sip DaemonSet (on SIP nodes)

4. **API Layer**:
   - api-server deployment

5. **UI Layer**:
   - webapp deployment

6. **Monitoring** (optional):
   - Homer, Jaeger, Telegraf, Grafana

---

## Your Use Case Architecture

For your specific requirements (SIP number routing, Facebook webhook integration, LLM/IVR):

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                  Your Application Flow                                   │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   ┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐     │
│   │  SIP Carriers    │          │  Facebook Lead   │          │  Your Webhook    │     │
│   │  (Inbound DIDs)  │          │  Form Webhooks   │          │  Application     │     │
│   │                  │          │                  │          │  (Node.js/Python)│     │
│   │  +1-555-100-XXXX │          │  POST /lead      │          │                  │     │
│   │  (Campaign A)    │          │                  │          │  - Lead matching │     │
│   │                  │          │                  │          │  - Call routing  │     │
│   │  +1-555-200-XXXX │          │                  │          │  - Bid logic     │     │
│   │  (Campaign B)    │          │                  │          │  - IVR flows     │     │
│   └────────┬─────────┘          └────────┬─────────┘          │  - LLM connect   │     │
│            │                             │                     └────────┬─────────┘     │
│            │                             │                              │               │
│            │                             │                              │               │
│            ▼                             ▼                              │               │
│   ┌──────────────────────────────────────────────────────────────────────────────────┐ │
│   │                              JAMBONZ PLATFORM                                     │ │
│   │                                                                                   │ │
│   │   ┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐       │ │
│   │   │   SBC Layer       │    │   Feature Server  │    │   API Server      │       │ │
│   │   │                   │    │                   │    │                   │       │ │
│   │   │   - SBC-SIP       │───▶│   - Call logic    │◀───│   - REST API      │◀──────┘ │
│   │   │   - SBC-Inbound   │    │   - IVR engine    │    │   - Create-call   │         │
│   │   │   - SBC-Outbound  │◀───│   - TTS/STT       │───▶│   - Update-call   │         │
│   │   │   - RTPEngine     │    │   - LLM proxy     │    │   - CDRs          │         │
│   │   │                   │    │   - Recording     │    │                   │         │
│   │   └───────────────────┘    └───────────────────┘    └───────────────────┘         │
│   │                                     │                                              │
│   │                                     │ Webhook callbacks                            │
│   │                                     ▼                                              │
│   └──────────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                              │
│                                         ▼                                              │
│   ┌──────────────────────────────────────────────────────────────────────────────────┐ │
│   │                             OUTBOUND DESTINATIONS                                 │ │
│   │                                                                                   │ │
│   │   ┌───────────────┐    ┌───────────────┐    ┌───────────────┐                   │ │
│   │   │  Call Centers │    │   Real Phone  │    │   SIP Devices │                   │ │
│   │   │  (SIP Trunk)  │    │   Numbers     │    │   (WebRTC)    │                   │ │
│   │   │               │    │   (PSTN)      │    │               │                   │ │
│   │   └───────────────┘    └───────────────┘    └───────────────┘                   │ │
│   │                                                                                   │ │
│   └──────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Recommended Components for Your Use Case

1. **Standard Jambonz Deployment** - All components as described above

2. **Your Custom Webhook Application** (external):
   - Receives Facebook Lead Form webhooks
   - Stores lead data with caller_id correlation
   - Implements bid/routing logic
   - Provides jambonz application webhooks for IVR/LLM flows

3. **LLM Integration Options**:
   - Use jambonz built-in `llm` verb for OpenAI/Anthropic
   - Or implement custom webhook for proprietary LLM

---

## Docker Images Reference

> **Note**: As of December 2025, all jambonz components are at version **0.9.5**. The helm-charts repository was archived in January 2024, so version tags are from direct Docker Hub/GitHub inspection.

| Component | Image | Latest Version (Dec 2025) | Node.js |
|-----------|-------|---------------------------|---------|
| feature-server | `jambonz/feature-server` | `0.9.5` | >= 18.x |
| sbc-inbound | `jambonz/sbc-inbound` | `0.9.5` | >= 20.0.0 |
| sbc-outbound | `jambonz/sbc-outbound` | `0.9.5` | >= 18.0.0 |
| sbc-sip-sidecar | `jambonz/sbc-sip-sidecar` | `0.9.5` | >= 20.0.0 |
| sbc-call-router | `jambonz/sbc-call-router` | `0.9.5` | >= 20.x |
| rtpengine-sidecar | `jambonz/rtpengine-sidecar` | `0.9.5` | >= 20.0.0 |
| rtpengine | `jambonz/rtpengine` | `11.5.1.31` | N/A (C) |
| api-server | `jambonz/api-server` | `0.9.5` | >= 18.x |
| webapp | `jambonz/webapp` | `0.9.5` | >= 18 |
| drachtio | `drachtio/drachtio-server` | `v0.9.4-rc2` | N/A (C++) |
| freeswitch | `drachtio/drachtio-freeswitch-mrf` | `1.10.10` (FreeSWITCH) | N/A (C) |
| smpp | `jambonz/smpp-esme` | `0.9.5` | >= 12.0.0 |

---

## Related Documentation

- [NETWORK_REQUIREMENTS.md](./NETWORK_REQUIREMENTS.md) - Network configuration for SIP/RTP nodes (EIP, Security Groups, routing)

---

## References

- [Jambonz Official Docs](https://www.jambonz.org/docs)
- [Jambonz Helm Charts](https://github.com/jambonz/helm-charts)
- [jambonz-feature-server](https://github.com/jambonz/jambonz-feature-server)
- [sbc-inbound](https://github.com/jambonz/sbc-inbound)
- [sbc-outbound](https://github.com/jambonz/sbc-outbound)
- [sbc-sip-sidecar](https://github.com/jambonz/sbc-sip-sidecar)
- [sbc-call-router](https://github.com/jambonz/sbc-call-router)
- [sbc-rtpengine-sidecar](https://github.com/jambonz/sbc-rtpengine-sidecar)
- [jambonz-api-server](https://github.com/jambonz/jambonz-api-server)
- [jambonz-webapp](https://github.com/jambonz/jambonz-webapp)
- [drachtio-server](https://github.com/drachtio/drachtio-server)
- [drachtio-freeswitch-mrf](https://github.com/drachtio/docker-drachtio-freeswitch-mrf)
