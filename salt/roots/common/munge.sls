{% set munge = salt['pillar.get']('infrastructure:common:munge') %}
{% set munge_package = munge['package'] %}
{% set munge_key = salt['pillar.get']('infrastructure:common:munge:key') %}

munge-package:
  pkg.installed:
    - name: {{ munge_package }}

/etc/munge/munge.key:
  file.managed:
    - name: /etc/munge/munge.key
    - contents: {{ munge_key | json }}
    - contents_newline: False
    - user: munge
    - group: munge
    - mode: 0400
    - show_changes: False
    - require:
        - pkg: munge-package

munge:
  service.running:
    - enable: True
    - require:
      - file: /etc/munge/munge.key
    - watch:
      - file: /etc/munge/munge.key
