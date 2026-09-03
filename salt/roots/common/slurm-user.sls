slurm-group:
  group.present:
    - name: slurm
    - system: True

slurm-user:
  user.present:
    - name: slurm
    - gid: slurm
    - shell: /usr/sbin/nologin
    - home: /nonexistent
    - createhome: False
    - system: True
    - require:
        - group: slurm-group