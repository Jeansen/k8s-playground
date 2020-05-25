# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# The :id special parameter is replaced with the ID of the virtual machine being created, 
DISKS = 8
NODES = 2

Vagrant.configure("2") do |config|

    #Your gatewway. In my case its a FritzBox
    gw = "192.168.178.1"

    config.vm.define "master.k8s", primary: true do |subconfig|
        subconfig.vm.provider "virtualbox" do |v|
            v.name = "master.k8s"
        end

        subconfig.vm.network "public_network", bridge: "wlan0", ip: "192.168.178.190"
        subconfig.vm.provision "shell",
            run: "always",
            inline: <<-SHELL
            hostnamectl --static set-hostname master.k8s;
            $(route -n | awk '{ if ($8 == "enp0s3" && $2 != "0.0.0.0") print "route del default gw " $2; }')
            route add default gw "#{gw}";
        SHELL
        subconfig.vm.provision "shell",
            inline: <<-SHELL
            kubeadm init --apiserver-advertise-address 192.168.178.190 | tee /out/master_init;
            mkdir -p /home/vagrant/.kube
            install /etc/kubernetes/admin.conf /home/vagrant/.kube/
            echo "export KUBECONFIG=/home/vagrant/.kube/admin.conf" >> /home/vagrant/.profile

            for i in dm_snapshot dm_mirror dm_thin_pool; do
                sudo modprobe $i
            done

            curl -s https://api.github.com/repos/heketi/heketi/releases/latest | grep 'browser_download_url' | awk '{print $2}' | grep 'heketi-v.*linux\.amd64' | tr -d '"' | wget -qi - -O - | tar xfzv -
            cp heketi/{heketi,heketi-cli} /usr/local/bin
  
            groupadd --system heketi
            useradd -s /sbin/nologin --system -g heketi heketi

            mkdir -p /var/lib/heketi /etc/heketi /var/log/heketi

            cp /in/heketi/heketi.json /etc/heketi
            cp /in/heketi/heketi.service /etc/systemd/system/
            cp /in/heketi/heketi.env /etc/heketi/
            chown -R heketi:heketi /var/lib/heketi /var/log/heketi /etc/heketi

            systemctl daemon-reload
        SHELL
    end

    (1..NODES).each do |i|
        config.vm.define "node#{i}.k8s", autostart: true do |subconfig|
            subconfig.vm.provider "virtualbox" do |v|
                v.name = "node#{i}.k8s"

                (1..DISKS).each do |d|
                    disk = "disks/#{v.name}-#{i}-#{d}.vdi"
                    unless File.exist?(disk)
                        v.customize ['createmedium', 'disk', '--filename', disk, '--variant', 'Standard', '--size', 500 * 1024]
                    end
                    v.customize ['storageattach', :id,  '--storagectl', 'SATA Controller', '--port', 1+d, '--type', 'hdd', '--nonrotational', 'on', '--medium', disk]
                end

            end

            subconfig.vm.network "public_network", bridge: "wlan0", ip: "192.168.178.19#{i}"
            #Note that sed has to use extra escapes. it actually is: sed 's/\\\s*//g'
            subconfig.vm.provision "shell",
                run: "always",
                inline: <<-SHELL
                hostnamectl --static set-hostname "node#{i}.k8s";
                $(route -n | awk '{ if ($8 == "enp0s3" && $2 != "0.0.0.0") print "route del default gw " $2; }');
                route add default gw "#{gw}";
            SHELL
            subconfig.vm.provision "shell",
                inline: <<-SHELL
                $(tail -n 2 /out/master_init | tr -d '\n' | sed 's/\\\\\s*//g')
            SHELL
            subconfig.vm.provision "shell",
                inline: <<-SHELL
            SHELL
        end
    end

    config.vm.box = "debian/contrib-buster64"

    config.vm.provision "shell", inline: <<-SHELL
        echo 'Acquire::http { Proxy "http://proxy:3142"; }' | tee -a /etc/apt/apt.conf.d/proxy
        apt update && apt upgrade -y && apt-get -y install gnupg2 apt-transport-https ca-certificates curl gnupg-agent software-properties-common net-tools
        curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -;
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -;
        echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list;
        echo 'deb https://download.docker.com/linux/debian stretch stable' > /etc/apt/sources.list.d/docker.list;
        swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab;
        apt update && apt install -y docker-ce kubelet kubeadm kubectl kubernetes-cni;

        #IPs here only needed when there is no DHCP
        echo 192.168.178.190  master.k8s >> /etc/hosts;
        for i in $(seq 1 2); do
            echo 192.168.178.19${i}  node${i}.k8s >> /etc/hosts;
        done
        
        apt install -y glusterfs-client glusterfs-server
        systemctl enable --now glusterd.service
    SHELL

    config.ssh.keep_alive = true
    config.vm.synced_folder "./out", "/out"
    config.vm.synced_folder "./in", "/in"
    config.vm.synced_folder "./keys", "/keys"
	config.vm.synced_folder ".", "/vagrant", disabled: true

    config.vm.provider "virtualbox" do |v|
      v.gui = false
      v.memory = 2048
      v.cpus = 2
    end

    config.trigger.before :all do |t|
        t.info = "Changing machine folder."
        t.run = {inline: "bash -c 'VBoxManage setproperty machinefolder $(pwd)/vm'"}
    end

    config.trigger.after :all do |t|
        t.info = "Changing machine folder back to default."
        t.run = {inline: "bash -c 'VBoxManage setproperty machinefolder default'"}
    end

end
