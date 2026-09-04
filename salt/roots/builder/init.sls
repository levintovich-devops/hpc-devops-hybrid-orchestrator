{% set builder_packages = salt['pillar.get']('builder:packages', []) %}
{% set slurm = salt['pillar.get']('builder:slurm', {}) %}
{% set slurm_version = slurm.get('version', '') %}
{% set slurm_source_base_url = slurm.get('source_base_url', '') %}
{% set slurm_sha256 = slurm.get('sha256', '') %}
{% set slurm_artifact_root = slurm.get('artifact_root', '') %}
{% set slurm_artifact_dir = slurm_artifact_root ~ '/' ~ slurm_version %}
{% set slurm_build_root = slurm.get('build_root', '') %}
{% set metrics_gateway = salt['pillar.get']('builder:metrics_gateway', {}) %}
{% set metrics_gateway_image_name = metrics_gateway.get('image_name', '') %}
{% set metrics_gateway_image_tag = metrics_gateway.get('image_tag', '') %}
{% set metrics_gateway_build_context = metrics_gateway.get('build_context', '') %}
{% set metrics_gateway_artifact_root = metrics_gateway.get('artifact_root', '') %}
{% set metrics_gateway_build_user = metrics_gateway.get('build_user', '') %}
{% set metrics_gateway_artifact_path = metrics_gateway_artifact_root ~ '/' ~ metrics_gateway_image_name ~ '-' ~ metrics_gateway_image_tag ~ '.tar' %}

salt-minion:
  service.dead:
    - enable: false

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
        - {{ metrics_gateway_artifact_root }}
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

build-metrics-gateway-image:
  cmd.run:
    - name: set -eu; rm -f "${METRICS_GATEWAY_ARTIFACT_PATH}.tmp"; podman build -t "${METRICS_GATEWAY_IMAGE_NAME}:${METRICS_GATEWAY_IMAGE_TAG}" --file Containerfile .; podman save -o "${METRICS_GATEWAY_ARTIFACT_PATH}.tmp" "${METRICS_GATEWAY_IMAGE_NAME}:${METRICS_GATEWAY_IMAGE_TAG}"; mv "${METRICS_GATEWAY_ARTIFACT_PATH}.tmp" "${METRICS_GATEWAY_ARTIFACT_PATH}"
    - cwd: {{ metrics_gateway_build_context | json }}
    - runas: {{ metrics_gateway_build_user | json }}
    - env:
        - METRICS_GATEWAY_IMAGE_NAME: {{ metrics_gateway_image_name | json }}
        - METRICS_GATEWAY_IMAGE_TAG: {{ metrics_gateway_image_tag | json }}
        - METRICS_GATEWAY_ARTIFACT_PATH: {{ metrics_gateway_artifact_path | json }}
    - creates: {{ metrics_gateway_artifact_path | json }}
    - require:
        - pkg: podman
        - file: builder-artifact-directories
