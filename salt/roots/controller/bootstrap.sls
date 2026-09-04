{% set salt_mysql = salt['pillar.get']('infrastructure:controller:salt_mysql') %}

salt-mysql-bootstrap:
  cmd.run:
    - name: salt-pip install '{{ salt_mysql['package'] }}[{{ salt_mysql['extra'] }}]=={{ salt_mysql['version'] }}'
    - unless: >-
        salt-pip show {{ salt_mysql['package'] }} | grep -Fqx "Version: {{ salt_mysql['version'] }}"
