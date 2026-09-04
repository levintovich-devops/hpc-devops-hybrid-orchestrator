{% set podman = salt['pillar.get']('infrastructure:controller:podman') %}
{% set exporter = salt['pillar.get']('infrastructure:controller:node_exporter') %}

controller-podman:
  pkg.installed:
    - name: {{ podman['package'] }}

/etc/systemd/system/{{ exporter['service_name'] }}.service:
  file.managed:
    - source: salt://controller/files/node-exporter.service.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 0644
    - require:
        - pkg: controller-podman

node-exporter-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: /etc/systemd/system/{{ exporter['service_name'] }}.service
    - require:
        - pkg: controller-podman

node-exporter-service:
  service.running:
    - name: {{ exporter['service_name'] }}
    - enable: True
    - watch:
        - file: /etc/systemd/system/{{ exporter['service_name'] }}.service
    - require:
        - pkg: controller-podman
        - cmd: node-exporter-systemd-reload
