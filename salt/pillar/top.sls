{% import_yaml "topology.sls" as topology %}

base:
  '*':
    - topology
  '{{ topology['topology']['nodes']['builder']['hostname'] }}':
    - builder
  '{{ topology['topology']['nodes']['controller']['hostname'] }}':
    - phase2.common
    - phase2.common-secrets
    - phase2.controller
    - phase2.controller-secrets
    - metrics-gateway
    - slurm_reporting
  '{{ topology['topology']['nodes']['compute']['hostname'] }}':
    - phase2.common
    - phase2.common-secrets
    - observability
    - metrics-gateway
    - slurm_reporting
