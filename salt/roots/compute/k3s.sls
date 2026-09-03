{% set k3s = salt['pillar.get']('observability:k3s') %}

k3s-prerequisites:
  pkg.installed:
    - pkgs:
        - curl
        - ca-certificates

k3s-install:
  cmd.run:
    - name: >-
        set -eu; installer=$(mktemp); trap 'rm -f "$installer"' EXIT;
        curl --fail --location https://get.k3s.io --output "$installer";
        INSTALL_K3S_VERSION={{ k3s['version'] }} INSTALL_K3S_EXEC="server" sh "$installer"
    - unless: /usr/local/bin/k3s --version | grep -Fq "{{ k3s['version'] }}"
    - require:
        - pkg: k3s-prerequisites

k3s:
  service.running:
    - name: {{ k3s['service'] }}
    - enable: True
    - require:
        - cmd: k3s-install

k3s-ready:
  cmd.run:
    - name: >-
        set -e; /usr/local/bin/k3s kubectl get --raw=/readyz;
        printf 'changed=no\n'
    - stateful: True
    - retry:
        attempts: 30
        interval: 10
        until: True
    - require:
        - service: k3s
