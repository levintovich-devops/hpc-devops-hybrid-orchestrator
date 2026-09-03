{% set slurm = salt['pillar.get']('phase2:common:slurm') %}
{% set cluster = salt['pillar.get']('phase2:common:cluster') %}
{% set artifact_dir = slurm['artifact_root'] ~ '/' ~ slurm['version'] %}
{% set version = slurm['version'] %}
{% set architecture = grains['osarch'] %}

slurm-compute-packages:
  pkg.installed:
    - sources:
      - {{ slurm['package_names']['common'] }}: {{ artifact_dir }}/{{ slurm['package_names']['common'] }}_{{ version }}-1_{{ architecture }}.deb
      - {{ slurm['package_names']['compute'] }}: {{ artifact_dir }}/{{ slurm['package_names']['compute'] }}_{{ version }}-1_{{ architecture }}.deb
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
        - pkg: slurm-compute-packages
        - user: slurm-user

{{ cluster['slurmd_spool_directory'] }}:
  file.directory:
    - user: root
    - group: root
    - mode: 0755
    - makedirs: True
    - require:
        - pkg: slurm-compute-packages
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

/var/log/slurm:
  file.directory:
    - user: root
    - group: root
    - mode: 0755
    - makedirs: True
    - require:
        - pkg: slurm-compute-packages
        - user: slurm-user

slurmd:
  service.running:
    - enable: True
    - require:
        - service: munge
        - pkg: slurm-compute-packages
        - file: /etc/slurm/slurm.conf
        - file: /var/log/slurm
    - watch:
        - file: /etc/slurm/slurm.conf
