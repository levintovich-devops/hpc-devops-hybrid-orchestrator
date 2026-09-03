# HPC DevOps Hybrid Orchestrator

## Quick access

Grafana: https://grafana.local

This URL works after the Windows hosts-file configuration described in [Access Grafana from Windows and Chrome](#access-grafana-from-windows-and-chrome).

## Project status

The currently verified implementation includes:

- Phase 1: Environment & Artifacts, complete and verified.
- Phase 2: Configuration Management with SaltStack, complete and verified.
- Phase 3: Observability and Orchestration with K3s, Helm, Prometheus, and Grafana, complete and verified.

Phase 4 Helm deployment of the Metrics Gateway and the Phase 5 functional Slurm reporting loop are not implemented. The complete technical assignment is not finished.

## Architecture

| Node | Address | Verified role | Resources |
| --- | --- | --- | --- |
| Builder | 192.168.56.10 | Ephemeral artifact builder; automatically powers off after successful builds | 4096 MB RAM, 4 CPUs |
| Controller | 192.168.56.11 | Salt Master, Podman, Controller Node Exporter, MariaDB, Munge, slurmdbd, and slurmctld | 2048 MB RAM, 2 CPUs |
| Compute | 192.168.56.12 | Salt Minion, Munge, slurmd, single-node K3s, kube-prometheus-stack, and Grafana | 4096 MB RAM, 2 CPUs |

The nodes use the existing private Vagrant network. Shared build and deployment artifacts are mounted at `/artifacts` on the VMs.

The Builder is a masterless Salt node and remains ephemeral. The Controller is a Salt Master without a Salt Minion service. The Compute node is the only Salt Minion and receives its states through the Controller.

## Prerequisites

Install or make available on the Windows host:

- Vagrant 2.4.9 or a compatible version
- VirtualBox or another supported Vagrant provider
- Git

```powershell
winget install Hashicorp.Vagrant
vagrant --version
```

## Deployment through Vagrant

Run the complete deployment from the repository root:

```bash
vagrant validate
vagrant up --provision
vagrant status
```

Expected final state:

- builder: poweroff
- controller: running
- compute: running

For reprovisioning existing running nodes, use this order:

```bash
vagrant provision controller
vagrant provision compute
```

Application installation and configuration must be performed through Vagrant and Salt automation. Direct SSH commands shown below are for validation and troubleshooting only.

## Builder artifacts

Run the complete Builder workflow from the repository root:

```bash
vagrant up builder --provision
```

Builder automatically powers off after successful artifact creation.

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

```bash
vagrant ssh controller -c "cd /artifacts/slurm-debs/26.05.3 && sha256sum -c SHA256SUMS"
vagrant ssh controller -c "test -s /artifacts/images/metrics-gateway-0.1.0.tar && echo 'Metrics Gateway image archive: OK'"
```

## Access Grafana from Windows and Chrome

The private Vagrant hostname is not registered in public DNS. Windows must resolve `grafana.local` locally.

Open Windows PowerShell as Administrator and run:

```powershell
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not (Select-String -Path $hostsFile -Pattern '^\s*192\.168\.56\.12\s+grafana\.local\s*$' -Quiet)) {
    Add-Content -Path $hostsFile -Value "`r`n192.168.56.12 grafana.local"
}
ipconfig /flushdns
```

Then open:

```text
https://grafana.local
```

Chrome may display a certificate warning because the local Traefik ingress uses a lab certificate. This is expected only for this private lab environment.

## Grafana credentials

Do not hardcode or document the Grafana password. From the repository root, connect to Compute:

```bash
vagrant ssh compute
```

After connecting to Compute, retrieve the credentials:

```bash

sudo k3s kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-user}' | base64 -d; echo
sudo k3s kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

The credentials are stored in a Kubernetes Secret and are not committed to Git.

## Grafana dashboard

1. Log in to Grafana.
2. Open **Dashboards**.
3. Select **Node Exporter Full**.
4. Select datasource `Prometheus`.
5. Select job `node-exporter`.
6. Select the required `Nodename` or `Instance`.

Controller and Compute metrics must both be available.

## Validation

The following commands validate the verified services and integrations.

From Controller SSH:

```bash
sudo salt 'compute' test.ping

for service in salt-master munge mariadb slurmdbd slurmctld node-exporter; do printf '%s: ' "$service"; systemctl is-active "$service"; done

sinfo -N -l

curl -fsS http://127.0.0.1:9100/metrics | head
```

From Compute SSH:

```bash
for service in salt-minion munge slurmd k3s; do printf '%s: ' "$service"; systemctl is-active "$service"; done

sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -n monitoring
sudo k3s kubectl get services -n monitoring
sudo k3s kubectl get ingress -n monitoring

curl -kI --resolve grafana.local:443:127.0.0.1 https://grafana.local
```

Prometheus target validation from Compute:

```bash
sudo k3s kubectl get --raw '/api/v1/namespaces/monitoring/services/http:monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/targets' | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(t["labels"].get("instance"), t["health"], t.get("lastError","")) for t in d["data"]["activeTargets"] if t["labels"].get("job")=="node-exporter"]'
```

Expected targets:

- `192.168.56.11:9100` up
- `192.168.56.12:9100` up

An additional K3s-managed Compute target such as `10.0.2.15:9100` may also appear and is valid.

## Troubleshooting

Useful status and inspection commands:

```bash
vagrant status
vagrant ssh controller
vagrant ssh compute
sudo systemctl status <service> --no-pager -l
sudo journalctl -u <service> --no-pager -n 100
sudo k3s kubectl get pods -n monitoring
sudo k3s kubectl describe pod <pod-name> -n monitoring
sudo k3s kubectl get events -n monitoring --sort-by=.lastTimestamp
```

A curl response with HTTP `302` and a `Location: /login` header confirms that the Grafana ingress is working.

## Idempotency

Re-run the node provisioning:

```bash
vagrant provision controller
vagrant provision compute
```

Expected Salt result: `Failed: 0` and no changed states.

Check monitoring pod identity, creation time, and restart count with:

```bash
sudo k3s kubectl get pods -n monitoring -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp,RESTARTS:.status.containerStatuses[*].restartCount'
```

Unchanged `UID` and `CREATED` values, together with zero additional restarts, confirm that the pods were not recreated.

## Secret handling

- Local Munge and MariaDB secrets are generated automatically by Vagrant when missing.
- Real secret files are ignored by Git.
- Only placeholder `.example` files are committed.
- Grafana credentials live in a Kubernetes Secret.
- Actual secret values must never be included in this README.

## AI usage

GitHub Copilot generated the Vagrant machine structure and resource allocation, Builder artifact automation, Controller and Compute Salt states, K3s and Helm automation, Prometheus additional scrape configuration, and Grafana ingress and dashboard provisioning. These generated components were used to make the multi-node environment reproducible, keep configuration data-driven, automate artifact creation, and provide repeatable observability deployment.

Manual review and correction covered malformed Salt configuration, secret handling, Munge key length, the MariaDB Salt dependency, Slurm user ordering, cluster registration idempotency, rootless Podman, safe artifact export, K3s readiness, Helm retry and idempotency, dashboard provider configuration, dashboard revision 45, and node-exporter job-name compatibility. The review also preserved the Controller-without-Minion architecture, the Compute-only Salt Minion role, Builder shutdown behavior, and the boundary that Phase 4 and Phase 5 remain unimplemented.

## Scope boundary

Phase 4 Metrics Gateway Helm deployment and Phase 5 functional Slurm reporting remain outside the current implementation. No claim is made that the complete assignment is finished.
