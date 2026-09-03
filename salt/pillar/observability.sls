observability:
  k3s:
    version: "v1.31.6+k3s1"
    service: k3s
  helm:
    version: "v3.16.4"
    repository_name: prometheus-community
    repository_url: https://prometheus-community.github.io/helm-charts
  monitoring:
    namespace: monitoring
    release_name: monitoring
    chart_name: prometheus-community/kube-prometheus-stack
    chart_version: "65.8.1"
    node_exporter_port: 9100
    grafana:
      host: grafana.local
      service_port: 3000
      ingress_entrypoint: websecure
      dashboard_id: 1860
      dashboard_revision: 45
    prometheus:
      service_port: 9090
