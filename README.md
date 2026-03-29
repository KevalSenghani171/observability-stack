# 🌐 Open Source Observability Stack  
### ⚙️ Terraform + ☸️ Kubernetes + 📦 Helm

<p align="center">
  <img src="https://img.shields.io/badge/Kubernetes-Ready-blue?logo=kubernetes" />
  <img src="https://img.shields.io/badge/Helm-Charts-0A0FFF?logo=helm" />
  <img src="https://img.shields.io/badge/Observability-Full%20Stack-green" />
  <img src="https://img.shields.io/badge/OpenTelemetry-Enabled-orange" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" />
</p>

---

## 📖 Overview

This repository provides a **complete, production-ready observability stack** using open-source tools to monitor:

- 📊 **Metrics**
- 📜 **Logs**
- 🔍 **Traces**

It leverages:
- ⚙️ **Terraform** → Infrastructure provisioning  
- 📦 **Helm** → Kubernetes deployments  
- ☸️ **Kubernetes** → Runtime platform  

---

## 🧩 Stack Components

### 🔄 CI/CD
- **GOCD**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/gocd/README.md  

---

### 📊 Monitoring & Visualization
- **Grafana**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/grafana/README.md  

- **Prometheus**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/prometheus/README.md  

---

### 🔍 Tracing & Telemetry
- **OpenTelemetry Operator**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/opentelemetry-operator/README.md  

- **Jaeger**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/jaeger/README.md  

- **Tempo**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/tempo/README.md  

---

### 📜 Logging
- **Loki**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/loki/README.md  

---

### ⚡ Data Pipeline / Agent
- **Alloy**  
  👉 https://github.com/KevalSenghani171/observability-stack/blob/main/alloy/README.md  

---

## 🏗️ Architecture Diagram

<p align="center">
  <img src="https://raw.githubusercontent.com/KevalSenghani171/observability-stack/main/docs/architecture.png" width="700"/>
</p>

### 🔽 Logical Flow
            ┌────────────────────┐
            │   Applications     │
            └─────────┬──────────┘
                      │
                      ▼
    ┌────────────────────────────────┐
    │ OpenTelemetry / Alloy Agents   │
    └─────────┬─────────┬────────────┘
              │         │
    ┌─────────▼───┐ ┌──▼─────────┐
    │ Prometheus  │ │   Loki     │
    │ (Metrics)   │ │  (Logs)    │
    └──────┬──────┘ └────┬───────┘
           │             │
           ▼             ▼
         Grafana Dashboards 📊📜

              │
              ▼
    ┌────────────────────┐
    │ Jaeger / Tempo     │
    │ (Tracing Backend)  │
    └─────────┬──────────┘
              ▼
        Distributed Traces 🔍


---

## 🚀 Features

✨ Fully open-source observability stack  
✨ Modular & scalable architecture  
✨ Kubernetes-native deployments  
✨ Supports distributed tracing  
✨ Unified dashboards via Grafana  
✨ Easy to extend and customize  

---

## 📸 Screenshots

Explore real working UI screenshots here:

👉 https://github.com/KevalSenghani171/observability-stack/tree/main/alloy/templates  

---

## ⚡ Quick Start

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/KevalSenghani171/observability-stack.git
cd observability-stack


cd terraform
terraform init
terraform apply