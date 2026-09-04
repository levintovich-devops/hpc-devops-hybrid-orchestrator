{% set database = salt['pillar.get']('infrastructure:controller:database') %}

mariadb-packages:
  pkg.installed:
    - pkgs:
        - mariadb-server

mariadb:
  service.running:
    - enable: True
    - require:
        - pkg: mariadb-packages

slurm-database:
  mysql_database.present:
    - name: {{ database['name'] | json }}
    - connection_unix_socket: /run/mysqld/mysqld.sock
    - require:
        - service: mariadb

slurm-database-user:
  mysql_user.present:
    - name: {{ database['username'] | json }}
    - host: {{ database['host'] | json }}
    - password: {{ database['password'] | json }}
    - connection_unix_socket: /run/mysqld/mysqld.sock
    - require:
        - service: mariadb

slurm-database-grants:
  mysql_grants.present:
    - grant: ALL PRIVILEGES
    - database: {{ (database['name'] ~ '.*') | json }}
    - user: {{ database['username'] | json }}
    - host: {{ database['host'] | json }}
    - grant_option: False
    - connection_unix_socket: /run/mysqld/mysqld.sock
    - require:
        - mysql_user: slurm-database-user
        - mysql_database: slurm-database
