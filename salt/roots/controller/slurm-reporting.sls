{% set reporting = salt['pillar.get']('slurm_reporting') %}

slurm-reporting-cron:
  pkg.installed:
    - name: cron

slurm-reporting-cron-service:
  service.running:
    - name: cron
    - enable: True
    - require:
        - pkg: slurm-reporting-cron

{{ reporting['job_script_path'] }}:
  file.managed:
    - source: salt://controller/files/slurm-reporting-job.sh.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 0755
    - makedirs: True
    - require:
        - service: slurmctld

{{ reporting['cron_file'] }}:
  file.managed:
    - contents: |
        SHELL=/bin/sh
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        {{ reporting['cron_schedule'] }} root /usr/bin/sbatch {{ reporting['job_script_path'] }} >> /var/log/slurm-reporting.log 2>&1
    - user: root
    - group: root
    - mode: 0644
    - require:
        - file: {{ reporting['job_script_path'] }}
        - service: slurm-reporting-cron-service
        - service: slurmctld
