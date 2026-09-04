metrics_gateway:
  image:
    repository: localhost/metrics-gateway
    name: metrics-gateway
    tag: "0.1.0"
  artifact:
    root: /artifacts/images
  release:
    name: metrics-gateway
    namespace: monitoring
  chart:
    path: /vagrant/helm/metrics-gateway
  service:
    port: 8080
    container_port: 8080
    node_port_enabled: true
    node_port: 30080
  service_monitor:
    enabled: true
    interval: 30s
    release_label: monitoring
    monitoring_label: metrics-gateway-monitor
