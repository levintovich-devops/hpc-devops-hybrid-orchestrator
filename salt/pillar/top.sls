{% import_yaml "topology.sls" as topology %}

base:
  '*':
    - topology
  '{{ topology['topology']['nodes']['builder']['hostname'] }}':
    - builder
  '{{ topology['topology']['nodes']['controller']['hostname'] }}':
    - infrastructure.common
    - infrastructure.common-secrets
    - infrastructure.controller
    - infrastructure.controller-secrets
    - metrics-gateway
    - slurm_reporting
  '{{ topology['topology']['nodes']['compute']['hostname'] }}':
    - infrastructure.common
    - infrastructure.common-secrets
    - observability
    - metrics-gateway
    - slurm_reporting
