slurm-reporting-curl:
  pkg.installed:
    - name: curl
    - require:
        - sls: compute.slurm
