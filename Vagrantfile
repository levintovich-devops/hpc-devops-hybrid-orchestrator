require "securerandom"
require "fileutils"

def ensure_secret_file(path, contents)
  return if File.exist?(path)

  directory = File.dirname(path)
  temporary_path = File.join(directory, ".#{File.basename(path)}.#{Process.pid}.#{SecureRandom.hex(8)}.tmp")

  begin
    File.open(temporary_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.write(contents)
      file.flush
      file.fsync
    end

    begin
      File.link(temporary_path, path)
    rescue Errno::EEXIST
      nil
    ensure
      FileUtils.rm_f(temporary_path)
    end
  ensure
    FileUtils.rm_f(temporary_path)
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  config.trigger.before [:up, :provision] do |trigger|
    trigger.ruby do
      pillar_directory = File.join(__dir__, "salt", "pillar", "phase2")
      FileUtils.mkdir_p(pillar_directory)

      ensure_secret_file(
        File.join(pillar_directory, "common-secrets.sls"),
        "phase2:\n  common:\n    munge:\n      key: \"#{SecureRandom.hex(64)}\"\n"
      )
      ensure_secret_file(
        File.join(pillar_directory, "controller-secrets.sls"),
        "phase2:\n  controller:\n    database:\n      password: \"#{SecureRandom.urlsafe_base64(32)}\"\n"
      )
    end
  end

  machines = [
    { name: "builder", ip: "192.168.56.10", memory: 4096, cpus: 4 },
    { name: "controller", ip: "192.168.56.11", memory: 2048, cpus: 2 },
    { name: "compute", ip: "192.168.56.12", memory: 4096, cpus: 2 }
  ]

  controller = machines.find { |machine| machine[:name] == "controller" }

  machines.each do |machine|
    config.vm.define machine[:name] do |node|
      node.vm.hostname = machine[:name]
      node.vm.network "private_network", ip: machine[:ip]
      node.vm.synced_folder "./artifacts", "/artifacts"

      node.vm.provider "virtualbox" do |vb|
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
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
        node.trigger.after :up do |trigger|
          trigger.only_on = "builder"
          trigger.run_remote = { inline: "sudo systemctl poweroff --no-block" }
        end
      end

      if machine[:name] == "controller"
        node.vm.synced_folder "./salt/roots", "/srv/salt"
        node.vm.synced_folder "./salt/pillar", "/srv/pillar"
        node.vm.provision "salt" do |salt|
          salt.install_master = true
          salt.no_minion = true
          salt.install_type = "stable"
          salt.run_highstate = false
          salt.verbose = true
          salt.master_config = "salt/config/controller-master"
        end
        node.vm.provision "shell", privileged: true, inline: <<-SHELL
          set -e
          salt-call --local --id controller --file-root=/srv/salt --pillar-root=/srv/pillar --retcode-passthrough state.apply controller.bootstrap
          salt-call --local --id controller --file-root=/srv/salt --pillar-root=/srv/pillar --retcode-passthrough state.highstate
        SHELL
      elsif machine[:name] == "compute"
        node.vm.provision "salt" do |salt|
          salt.install_type = "stable"
          salt.run_highstate = true
          salt.verbose = true
          salt.minion_json_config = {
            "master" => controller[:ip],
            "id" => machine[:name]
          }.to_json
        end
      end
    end
  end
end
