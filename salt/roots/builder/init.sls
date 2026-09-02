{% set builder_packages = salt['pillar.get']('builder:packages', []) %}
{% set slurm = salt['pillar.get']('builder:slurm', {}) %}
{% set slurm_version = slurm.get('version', '') %}
{% set slurm_source_base_url = slurm.get('source_base_url', '') %}
{% set slurm_sha256 = slurm.get('sha256', '') %}
{% set slurm_artifact_root = slurm.get('artifact_root', '') %}
{% set slurm_artifact_dir = slurm_artifact_root ~ '/' ~ slurm_version %}
{% set slurm_build_root = slurm.get('build_root', '') %}

builder_packages:
  pkg.installed:
    - pkgs: {{ builder_packages }}

podman:
  pkg.installed:
    - name: podman

builder-artifact-directories:
  file.directory:
    - names:
        - {{ slurm_artifact_root }}
        - /artifacts/images
    - makedirs: True

/usr/local/bin/build-slurm-debs:
  file.managed:
    - source: salt://builder/files/build-slurm-debs.sh
    - mode: 0755

build-slurm-debs:
  cmd.run:
    - name: /usr/local/bin/build-slurm-debs
    - env:
        - SLURM_VERSION: {{ slurm_version | json }}
        - SLURM_SOURCE_BASE_URL: {{ slurm_source_base_url | json }}
        - SLURM_SHA256: {{ slurm_sha256 | json }}
        - SLURM_ARTIFACT_ROOT: {{ slurm_artifact_root | json }}
        - SLURM_BUILD_ROOT: {{ slurm_build_root | json }}
    - creates: {{ slurm_artifact_dir }}/.complete
    - require:
        - pkg: builder_packages
        - file: /usr/local/bin/build-slurm-debs
        - file: builder-artifact-directories
