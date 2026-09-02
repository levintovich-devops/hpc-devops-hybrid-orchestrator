Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  machines = [
    { name: "builder", ip: "192.168.56.10", memory: 4096, cpus: 4 },
    { name: "controller", ip: "192.168.56.11" },
    { name: "compute", ip: "192.168.56.12" }
  ]

  controller = machines.find { |machine| machine[:name] == "controller" }
  compute = machines.find { |machine| machine[:name] == "compute" }

  machines.each do |machine|
    config.vm.define machine[:name] do |node|
      node.vm.hostname = machine[:name]
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.synced_folder "./artifacts", "/artifacts"

      node.vm.provider "virtualbox" do |vb|
        if machine[:name] == "builder"
          vb.memory = machine[:memory]
          vb.cpus = machine[:cpus]
        end
      end

      if machine[:name] == "builder"
        node.vm.synced_folder "./salt/roots", "/srv/salt"
        node.vm.synced_folder "./salt/pillar", "/srv/pillar"
        node.vm.provision "salt" do |salt|
          salt.masterless = true
          salt.install_type = "stable"
          salt.run_highstate = true
          salt.verbose = true
          salt.minion_config = "salt/config/builder-minion"
          salt.minion_id = machine[:name]
        end
      end

      if machine[:name] == "controller"
        node.vm.provision "salt" do |salt|
          salt.install_master = true
          salt.no_minion = true
          salt.install_type = "stable"
          salt.run_highstate = false
          salt.verbose = true
          salt.master_json_config = <<~JSON
            {
              "file_roots": {
                "base": ["/srv/salt"]
              },
              "auto_accept": true,
              "interface": "#{controller[:ip]}"
            }
          JSON
        end
      elsif machine[:name] == "compute"
        node.vm.provision "salt" do |salt|
          salt.install_type = "stable"
          salt.run_highstate = false
          salt.verbose = true
          salt.minion_json_config = <<~JSON
            {
              "master": "#{controller[:ip]}",
              "id": "#{compute[:name]}"
            }
          JSON
        end
      end
    end
  end
end
