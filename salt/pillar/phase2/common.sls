phase2:
  common:
    cluster_name: hpc-lab
    cluster:
      slurm_user: slurm
      slurmctld_port: 6817
      slurmd_port: 6818
      slurmdbd_port: 6819
      state_save_directory: /var/lib/slurmctld
      slurmd_spool_directory: /var/lib/slurmd
      slurmctld_log: /var/log/slurm/slurmctld.log
      slurmd_log: /var/log/slurm/slurmd.log
      slurmdbd_log: /var/log/slurm/slurmdbd.log
    munge:
      package: munge
    slurm:
      version: "26.05.3"
      artifact_root: /artifacts/slurm-debs
      package_names:
        common: slurm-smd
        client: slurm-smd-client
        controller: slurm-smd-slurmctld
        database: slurm-smd-slurmdbd
        compute: slurm-smd-slurmd
