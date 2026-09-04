base:
  'builder':
    - builder
  'controller':
    - phase2.common
    - phase2.common-secrets
    - phase2.controller
    - phase2.controller-secrets
    - metrics-gateway
    - slurm_reporting
  'compute':
    - phase2.common
    - phase2.common-secrets
    - observability
    - metrics-gateway
    - slurm_reporting
