{% set slurm = salt['pillar.get']('phase2:common:slurm') %}
{% set cluster = salt['pillar.get']('phase2:common:cluster') %}
{% set artifact_dir = slurm['artifact_root'] ~ '/' ~ slurm['version'] %}
{% set version = slurm['version'] %}
{% set architecture = grains['osarch'] %}

slurm-controller-packages:
  pkg.installed:
    - sources:
      - {{ slurm['package_names']['common'] }}: {{ artifact_dir }}/{{ slurm['package_names']['common'] }}_{{ version }}-1_{{ architecture }}.deb
      - {{ slurm['package_names']['client'] }}: {{ artifact_dir }}/{{ slurm['package_names']['client'] }}_{{ version }}-1_{{ architecture }}.deb
      - {{ slurm['package_names']['controller'] }}: {{ artifact_dir }}/{{ slurm['package_names']['controller'] }}_{{ version }}-1_{{ architecture }}.deb
      - {{ slurm['package_names']['database'] }}: {{ artifact_dir }}/{{ slurm['package_names']['database'] }}_{{ version }}-1_{{ architecture }}.deb
    - require:
        - sls: common.slurm-user
        - service: munge

/etc/slurm:
  file.directory:
    - user: root
    - group: root
    - mode: 0755
    - makedirs: True
    - require:
        - pkg: slurm-controller-packages
        - user: slurm-user

{{ cluster['state_save_directory'] }}:
  file.directory:
    - user: slurm
    - group: slurm
    - mode: 0755
    - makedirs: True
    - require:
        - pkg: slurm-controller-packages
        - user: slurm-user

/var/log/slurm:
  file.directory:
    - user: slurm
    - group: slurm
    - mode: 0755
    - makedirs: True
    - require:
        - pkg: slurm-controller-packages
        - user: slurm-user

/etc/slurm/slurm.conf:
  file.managed:
    - source: salt://common/files/slurm.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 0644
    - require:
        - file: /etc/slurm
        - user: slurm-user

/etc/slurm/slurmdbd.conf:
  file.managed:
    - source: salt://controller/files/slurmdbd.conf.jinja
    - template: jinja
    - user: slurm
    - group: slurm
    - mode: 0600
    - show_changes: False
    - require:
        - file: /etc/slurm
        - user: slurm-user

slurm-cluster-registration:
  cmd.run:
    - name: sacctmgr -i add cluster {{ salt['pillar.get']('phase2:common:cluster_name') }}
    - unless: sacctmgr --noheader --parsable2 show cluster {{ salt['pillar.get']('phase2:common:cluster_name') }} format=Cluster | grep -Fqx "{{ salt['pillar.get']('phase2:common:cluster_name') }}"
    - require:
        - service: slurmdbd
        - pkg: slurm-controller-packages

slurmdbd:
  service.running:
    - enable: True
    - require:
        - service: mariadb
        - service: munge
        - mysql_grants: slurm-database-grants
        - pkg: slurm-controller-packages
        - file: /etc/slurm/slurm.conf
        - file: /etc/slurm/slurmdbd.conf
    - watch:
        - file: /etc/slurm/slurm.conf
        - file: /etc/slurm/slurmdbd.conf

slurmctld:
  service.running:
    - enable: True
    - require:
        - service: slurmdbd
        - cmd: slurm-cluster-registration
        - service: munge
        - file: /etc/slurm/slurm.conf
    - watch:
        - file: /etc/slurm/slurm.conf
