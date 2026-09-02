builder:
  packages:
    - build-essential
    - fakeroot
    - devscripts
    - equivs
    - curl
    - ca-certificates
    - bzip2
    - pkg-config
    - git
    - python3
  slurm:
    version: "26.05.3"
    source_base_url: "https://download.schedmd.com/slurm"
    sha256: "f4219b15b8e4e8dc2559052abfd760759598867cd28051896d3b09c0a06a2ab7"
    artifact_root: "/artifacts/slurm-debs"
    build_root: "/var/tmp/slurm-build"
