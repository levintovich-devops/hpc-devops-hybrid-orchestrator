# HPC DevOps Hybrid Orchestrator Implementation Guide

## Project status

The verified implementation includes:

- Phase 1: Environment and artifacts.
- Phase 2: Configuration management with SaltStack.
- Phase 3: Observability and orchestration with K3s, Helm, Prometheus, and Grafana.
- Phase 4: Metrics Gateway deployment and Prometheus integration.
- Phase 5: Slurm reporting automation and the Live Slurm Job Load dashboard.

## Architecture

| Node | Address | Verified role | Resources |
| --- | --- | --- | --- |
| Builder | 192.168.56.10 | Ephemeral artifact builder; automatically powers off after builds | 4096 MB RAM, 4 CPUs |
| Controller | 192.168.56.11 | Salt Master without a Minion, Podman, Node Exporter, MariaDB, Munge, slurmdbd, and slurmctld | 2048 MB RAM, 2 CPUs |
| Compute | 192.168.56.12 | Only Salt Minion, Munge, slurmd, single-node K3s, kube-prometheus-stack, and Grafana | 4096 MB RAM, 2 CPUs |

The nodes use the private Vagrant network. Shared build and deployment artifacts are mounted at `/artifacts` on the VMs. The Builder remains powered off after artifact creation. Controller is a Salt Master without a Salt Minion service. Compute is the only Salt Minion and receives its states through Controller.

## Prerequisites

Install or make available on the Windows host:

- Vagrant 2.4.9 or a compatible version
- VirtualBox (verified provider)
- Git

Optional version check:

```powershell
vagrant --version
```

## Deployment through Vagrant

From a clean clone, deploy the complete environment with:

```powershell
vagrant up --provision
```

Expected final state:

- builder: poweroff
- controller: running
- compute: running

For reprovisioning existing running nodes, use this order:

```powershell
vagrant provision controller
vagrant provision compute
```

Application installation and configuration are performed through Vagrant and Salt automation. Direct SSH commands in this guide are for validation and troubleshooting only.

## Builder artifacts

The Builder workflow creates the Slurm packages and Metrics Gateway image, then powers off the Builder:

```powershell
vagrant up builder --provision
```

Slurm artifacts:

```text
host: artifacts/slurm-debs/26.05.3
VM: /artifacts/slurm-debs/26.05.3
```

Metrics Gateway image:

```text
host: artifacts/images/metrics-gateway-0.1.0.tar
VM: /artifacts/images/metrics-gateway-0.1.0.tar
```

Because Builder is powered off, verify shared artifacts through Controller:

```powershell
vagrant ssh controller -c "cd /artifacts/slurm-debs/26.05.3 && sha256sum -c SHA256SUMS"
vagrant ssh controller -c "test -s /artifacts/images/metrics-gateway-0.1.0.tar && echo 'Metrics Gateway image archive: OK'"
```

## Grafana access

The Grafana URL is:

```text
https://grafana.local
```

The private Vagrant hostname is not registered in public DNS. Open Windows PowerShell as Administrator and add the Compute address to the hosts file:

```powershell
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not (Select-String -Path $hostsFile -Pattern '^\s*192\.168\.56\.12\s+grafana\.local\s*$' -Quiet)) {
    Add-Content -Path $hostsFile -Value "`r`n192.168.56.12 grafana.local"
}
ipconfig /flushdns
```

Chrome may display a certificate warning because the local Traefik ingress uses a lab certificate. This is expected for this private lab environment.

## Grafana credentials

From the repository root, connect to Compute:

```powershell
vagrant ssh compute
```

Retrieve the credentials from the Kubernetes Secret without placing them in project files:

```bash
sudo k3s kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-user}' | base64 -d; echo
sudo k3s kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## Grafana dashboards

The automated dashboards are:

- **Node Exporter Full**: host and node-exporter health metrics.
- **Live Slurm Job Load**: CPU, GPU, and memory load samples reported by Slurm jobs, with `job_id` and `node` selectors.

The dashboard datasource is the existing Prometheus datasource. No dashboard changes are made manually through the Grafana UI.

## Phase 4: Metrics Gateway

The Metrics Gateway is packaged as a local container image and deployed to the single-node K3s cluster through the `helm/metrics-gateway` chart. Salt imports the image, renders Helm values from Pillar, and performs an idempotent Helm upgrade/install in the `monitoring` namespace.

The gateway API provides:

- `PUT /update-metric`: accepts JSON containing `metric_name`, `value`, and `labels`.
- `GET /metrics`: exposes the in-memory values in Prometheus text format.

The existing ClusterIP Service is retained for in-cluster access. A configurable NodePort also exposes the gateway on Compute for Slurm jobs. The NodePort is configured in Salt Pillar and rendered into Helm values; VM addresses are taken from existing Pillar values rather than hardcoded in deployment logic.

The ServiceMonitor selects only the dedicated monitoring label on the ClusterIP Service, preventing the NodePort Service from creating a duplicate Prometheus scrape target. Prometheus is configured with the existing Node Exporter targets as well.

## Phase 5: Slurm reporting

Controller owns the Salt-managed reporting script and `/etc/cron.d/slurm-reporting`. Cron is enabled and running on Controller, and submits the script with `sbatch` every five minutes. The submitted job is scheduled and executed by the Compute `slurmd` node. Compute receives `curl` through Salt; the job script itself is transferred by Slurm and is not separately installed on Compute.

Inside the running job:

- `SLURM_JOB_ID` and `SLURMD_NODENAME` are required and used as the `job_id` and `node` labels.
- CPU, GPU, and memory values are independently simulated in the range 0 to 100. They are not hardware measurements.
- Twelve samples are sent at five-second intervals for a complete 60-second run.
- Each request is a `PUT /update-metric` JSON payload containing `metric_name`, `value`, and the `job_id` and `node` labels.
- The job has a clear name, a two-minute time limit, and writes Slurm output under `/var/log/slurm` using the Slurm job ID.

Deployment-specific metric names are managed through Salt Pillar and rendered into the job script and Helm values. The Helm chart also contains standalone defaults. The **Live Slurm Job Load** dashboard uses one time-series panel with separate CPU, GPU, and memory queries and provides `job_id` and `node` variables.

## Validation

### Salt Master and Minion

From Controller:

```bash
sudo systemctl is-active salt-master
sudo salt 'compute' test.ping
sudo salt-key -L
sudo salt 'compute' grains.item id os osrelease
```

From Compute:

```bash
sudo systemctl is-active salt-minion
sudo salt-call test.version
```

### Munge and Slurm

From Controller:

```bash
for service in munge mariadb slurmdbd slurmctld; do printf '%s: ' "$service"; systemctl is-active "$service"; done
sudo sha256sum /etc/munge/munge.key
sudo salt 'compute' cmd.run 'sha256sum /etc/munge/munge.key'
sinfo -N -l
squeue
sacct
```

From Compute:

```bash
for service in munge slurmd; do printf '%s: ' "$service"; systemctl is-active "$service"; done
sudo systemctl status slurmd --no-pager -l
sinfo -N -l
```

### K3s and observability

From Compute:

```bash
sudo systemctl is-active k3s
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -n monitoring
sudo k3s kubectl get services -n monitoring
sudo k3s kubectl get ingress -n monitoring
sudo k3s kubectl get servicemonitor -n monitoring
```

Prometheus active targets:

```bash
sudo k3s kubectl get --raw '/api/v1/namespaces/monitoring/services/http:monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/targets' | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(t["labels"].get("instance"), t["health"], t.get("lastError","")) for t in d["data"]["activeTargets"]]'
```

Expected Node Exporter targets include the Controller and Compute addresses on port `9100`, both up. An additional K3s-managed Compute target may also appear and is valid.

### Metrics Gateway and Prometheus

From Compute:

```bash
sudo k3s kubectl get deployment metrics-gateway -n monitoring
sudo k3s kubectl get service -n monitoring -l app.kubernetes.io/name=metrics-gateway
sudo k3s kubectl get servicemonitor -n monitoring metrics-gateway -o yaml
curl -fsS -X PUT "http://192.168.56.12:30080/update-metric" -H 'Content-Type: application/json' -d '{"metric_name":"slurm_job_cpu_load","value":42.5,"labels":{"job_id":"validation","node":"compute"}}'
curl -fsS http://192.168.56.12:30080/metrics
sudo k3s kubectl get --raw '/api/v1/namespaces/monitoring/services/http:monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query?query=slurm_job_cpu_load'
```

The direct Gateway checks use the configured lab NodePort and are validation commands only. Production configuration continues to source addresses and ports from Pillar.

### Slurm reporting loop

From Controller:

```bash
sudo cat /etc/cron.d/slurm-reporting
sudo systemctl is-active cron
squeue -a
sacct -X --starttime=now-30minutes
sudo tail -n 100 /var/log/slurm-reporting.log
```

Use multiple completed or running job IDs when checking the dashboard selectors and Prometheus series:

```bash
sacct -X --starttime=now-2hours --format=JobID,JobName,State,NodeList
```

The job is submitted from Controller but executes on Compute. The `job_id` and `node` labels should identify each reporting run independently.

From Compute, inspect the Slurm job output files:

```bash
sudo ls -l /var/log/slurm/slurm-reporting-*.out
```

### Idempotency and restart checks

Re-run provisioning in the documented order:

```powershell
vagrant provision controller
vagrant provision compute
```

Expected Salt result: `Failed: 0`; unchanged resources should report no changes.

Check monitoring pod identity, creation time, and restart count:

```bash
sudo k3s kubectl get pods -n monitoring -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp,RESTARTS:.status.containerStatuses[*].restartCount'
```

Unchanged `UID` and `CREATED` values, with no unexpected increase in restart counts, confirm that pods were not recreated. Controller and Compute Salt states are designed to be idempotent, including package installation, managed files, cron configuration, image import markers, and Helm release markers.

## Troubleshooting

From the Windows repository root:

```powershell
vagrant status
vagrant ssh controller
vagrant ssh compute
```

Inside the relevant VM:

```bash
sudo systemctl status <service> --no-pager -l
sudo journalctl -u <service> --no-pager -n 100
sudo journalctl -u salt-master --no-pager -n 100
sudo journalctl -u salt-minion --no-pager -n 100
sudo k3s kubectl get pods -n monitoring
sudo k3s kubectl describe pod <pod-name> -n monitoring
sudo k3s kubectl get events -n monitoring --sort-by=.lastTimestamp
sudo journalctl -u cron --no-pager -n 100
sudo journalctl -u slurmd --no-pager -n 100
```

A curl response with HTTP `302` and a `Location: /login` header confirms that the Grafana ingress is working:

```bash
curl -kI --resolve grafana.local:443:127.0.0.1 https://grafana.local
```

For reporting failures, inspect the cron log, Slurm accounting state, the job output under `/var/log/slurm`, and the Gateway metrics endpoint. Confirm that the NodePort Service exists, that the Compute node is reachable from the job, and that Prometheus sees the resulting metric series.

## Secret handling

- Local Munge and MariaDB secrets are generated automatically by Vagrant when missing.
- Real secret files are ignored by Git.
- Only placeholder `.example` files are committed.
- Grafana credentials live in a Kubernetes Secret.
- Secret values, Munge keys, hashes, and passwords must never be included in project documentation.

## AI usage

GitHub Copilot drafted the data-driven Vagrant topology and resource configuration; Builder Salt states, Slurm packaging, checksums, image build, export, and shutdown; Controller and Compute Salt states; Podman Node Exporter, MariaDB, Munge, and Slurm configuration; K3s, Helm, Prometheus, Grafana ingress and dashboards; the Metrics Gateway Helm deployment; and the scheduled Slurm reporting script and dashboard. AI was used to reduce duplicated configuration and accelerate repeatable infrastructure-as-code generation.

The generated output was manually reviewed, corrected, and validated. Human review and runtime validation corrected malformed Salt configuration; secret generation and Git exclusions; Munge key length; MariaDB Salt dependencies; Slurm user ordering and cluster-registration idempotency; rootless Podman and safe artifact export; remote Builder shutdown; K3s readiness and Helm idempotency; Prometheus job-name compatibility; Grafana dashboard revision and datasource; Controller Node Exporter hostname isolation; Metrics Gateway image import and duplicate ServiceMonitor selection; and Phase 5 Pillar availability, cron dependencies, independent simulated values, and exact 60-second execution. AI did not perform the runtime verification.
