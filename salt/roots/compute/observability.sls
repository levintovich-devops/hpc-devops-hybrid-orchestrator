{% set helm = salt['pillar.get']('observability:helm') %}
{% set monitoring = salt['pillar.get']('observability:monitoring') %}
{% set grafana = monitoring['grafana'] %}
{% set prometheus = monitoring['prometheus'] %}
{% set controller_address = salt['pillar.get']('topology:nodes:controller:ip') %}
{% set compute_address = salt['pillar.get']('topology:nodes:compute:ip') %}
{% set node_exporter_port = monitoring['node_exporter_port'] %}
helm-install:
  cmd.run:
    - name: >-
        set -eu; temporary_directory=$(mktemp -d); trap 'rm -rf "$temporary_directory"' EXIT;
        curl -fsSL "https://get.helm.sh/helm-{{ helm['version'] }}-linux-{{ grains['osarch'] }}.tar.gz"
        -o "$temporary_directory/helm.tar.gz";
        tar -xzf "$temporary_directory/helm.tar.gz" -C "$temporary_directory";
        install -m 0755 "$temporary_directory/linux-{{ grains['osarch'] }}/helm" /usr/local/bin/helm
    - unless: helm version --short | sed 's/+.*//' | grep -Fqx '{{ helm['version'] }}'
    - require:
        - cmd: k3s-ready

prometheus-community-repository:
  cmd.run:
    - name: helm repo add {{ helm['repository_name'] }} {{ helm['repository_url'] }}
    - unless: helm repo list | grep -Fq "{{ helm['repository_name'] }}"
    - require:
        - cmd: k3s-ready
        - cmd: helm-install

monitoring-namespace:
  cmd.run:
    - name: /usr/local/bin/k3s kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml create namespace {{ monitoring['namespace'] }}
    - unless: /usr/local/bin/k3s kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get namespace {{ monitoring['namespace'] }}
    - require:
        - cmd: k3s-ready

/etc/rancher/k3s/monitoring-values.yaml:
  file.managed:
    - contents: |
        grafana:
          service:
            port: {{ grafana['service_port'] }}
          dashboardProviders:
            dashboardproviders.yaml:
              apiVersion: 1
              providers:
                - name: default
                  orgId: 1
                  folder: ""
                  type: file
                  disableDeletion: false
                  editable: true
                  options:
                    path: /var/lib/grafana/dashboards/default
          ingress:
            enabled: true
            ingressClassName: traefik
            annotations:
              traefik.ingress.kubernetes.io/router.entrypoints: {{ grafana['ingress_entrypoint'] | json }}
              traefik.ingress.kubernetes.io/router.tls: "true"
            hosts:
              - {{ grafana['host'] }}
            tls:
              - hosts:
                  - {{ grafana['host'] }}
          dashboards:
            default:
              node-exporter-full:
                gnetId: {{ grafana['dashboard_id'] }}
                revision: {{ grafana['dashboard_revision'] }}
                datasource: Prometheus
        prometheus:
          service:
            port: {{ prometheus['service_port'] }}
          prometheusSpec:
            additionalScrapeConfigs:
              - job_name: node-exporter
                static_configs:
                  - targets:
                      - {{ (controller_address ~ ':' ~ node_exporter_port) | json }}
                      - {{ (compute_address ~ ':' ~ node_exporter_port) | json }}
    - user: root
    - group: root
    - mode: 0644
    - require:
        - cmd: k3s-ready

monitoring-stack:
  cmd.run:
    - name: >-
        set -eu; marker=/var/lib/rancher/k3s/monitoring-stack.signature;
        values_hash=$(sha256sum /etc/rancher/k3s/monitoring-values.yaml | awk '{print $1}');
        requested_signature="${values_hash}|{{ monitoring['chart_version'] }}";
        if test -f "$marker" && grep -Fqx "$requested_signature" "$marker" && helm status {{ monitoring['release_name'] }} --namespace {{ monitoring['namespace'] }} --kubeconfig /etc/rancher/k3s/k3s.yaml --output json | tr -d '[:space:]' | grep -Fq '"status":"deployed"'; then exit 0; fi;
        helm repo add {{ helm['repository_name'] }} {{ helm['repository_url'] }} --force-update;
        helm upgrade --install {{ monitoring['release_name'] }} {{ monitoring['chart_name'] }}
        --version {{ monitoring['chart_version'] }}
        --namespace {{ monitoring['namespace'] }}
        --create-namespace
        --kubeconfig /etc/rancher/k3s/k3s.yaml
        --values /etc/rancher/k3s/monitoring-values.yaml
        --wait --timeout 10m;
        temporary_marker="$marker.$$.tmp";
        printf '%s\n' "$requested_signature" > "$temporary_marker";
        mv "$temporary_marker" "$marker"
    - unless: >-
        test -f /var/lib/rancher/k3s/monitoring-stack.signature
        && test "$(sha256sum /etc/rancher/k3s/monitoring-values.yaml | awk '{print $1}')|{{ monitoring['chart_version'] }}" = "$(cat /var/lib/rancher/k3s/monitoring-stack.signature)"
        && helm status {{ monitoring['release_name'] }} --namespace {{ monitoring['namespace'] }} --kubeconfig /etc/rancher/k3s/k3s.yaml --output json | tr -d '[:space:]' | grep -Fq '"status":"deployed"'
    - require:
        - cmd: k3s-ready
        - cmd: prometheus-community-repository
        - cmd: monitoring-namespace
        - file: /etc/rancher/k3s/monitoring-values.yaml
