# HPC DevOps Hybrid Orchestrator Architecture

## 1. Infrastructure Topology

```mermaid
flowchart TB
    subgraph host["Windows Host — Vagrant + VirtualBox"]
        direction TB
        builder["Builder"]
        artifacts["Shared artifacts"]
        controller["Controller — Salt Master"]
        compute["Compute — Salt Minion"]
        k3s["K3s monitoring"]

        builder -->|"creates"| artifacts
        artifacts -->|"DEB packages"| controller
        artifacts -->|"DEBs + image"| compute
        controller -->|"Salt + Slurm"| compute
        compute -->|"hosts"| k3s
    end
```

Vagrant and VirtualBox run the three-node environment. Builder creates shared artifacts, Controller manages Compute with Salt and Slurm, and Compute hosts K3s monitoring.

## 2. Observability Data Flow

```mermaid
flowchart LR
    controller["Controller<br/>Node Exporter"]
    compute["Compute<br/>Node Exporter"]
    gateway["Metrics Gateway"]
    prometheus["Prometheus"]
    grafana["Grafana"]

    controller --> prometheus
    compute --> prometheus
    gateway --> prometheus
    prometheus --> grafana
```

Node Exporters and Metrics Gateway expose metrics. Prometheus scrapes and stores those metrics. Grafana queries Prometheus and visualizes the data.

## 3. Hybrid Loop

```mermaid
flowchart TB
    cron["Scheduled cron"]
    submit["Slurm submission"]
    compute["Execution on Compute"]
    report["CPU / GPU / Memory"]
    gateway["Metrics Gateway"]
    prometheus["Prometheus"]
    grafana["Grafana"]

    cron --> submit
    submit --> compute
    compute --> report
    report --> gateway
    gateway --> prometheus
    prometheus --> grafana
```

Cron submits a Slurm job to Compute. The job reports CPU, GPU, and memory values through the Metrics Gateway to Prometheus and Grafana.
