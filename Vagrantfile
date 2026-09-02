Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  machines = [
    { name: "builder", ip: "192.168.56.10" },
    { name: "controller", ip: "192.168.56.11" },
    { name: "compute", ip: "192.168.56.12" }
  ]

  machines.each do |machine|
    config.vm.define machine[:name] do |node|
      node.vm.network "private_network", ip: machine[:ip]
    end
  end
end
