phase2:
  controller:
    database:
      name: slurm_acct_db
      username: slurm
      host: localhost
      port: 3306
    podman:
      package: podman
    node_exporter:
      image: quay.io/prometheus/node-exporter:v1.8.2
      container_name: node-exporter
      service_name: node-exporter
      port: 9100
    salt_mysql:
      package: saltext.mysql
      extra: pymysql
      version: "1.1.0"
