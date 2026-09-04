slurm_reporting:
  job_script_path: /usr/local/libexec/slurm-reporting-job.sh
  cron_file: /etc/cron.d/slurm-reporting
  cron_schedule: "*/5 * * * *"
  gateway_path: /update-metric
  interval_seconds: 5
  duration_seconds: 60
  metrics:
    cpu: slurm_job_cpu_load
    gpu: slurm_job_gpu_load
    memory: slurm_job_memory_load
