{% set builder_packages = salt['pillar.get']('builder:packages', []) %}

builder_packages:
  pkg.installed:
    - pkgs: {{ builder_packages }}

podman:
  pkg.installed:
    - name: podman

builder-artifact-directories:
  file.directory:
    - names:
        - /artifacts/slurm-debs
        - /artifacts/images
    - makedirs: True
