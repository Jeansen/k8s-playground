# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# The :id special parameter is replaced with the ID of the virtual machine being created, 
LIBVIRT_DEFAULT_URI = ENV['LIBVIRT_DEFAULT_URI'] || 'qemu:///system' 
DISKS = 2
NODES = 2

Vagrant.configure('2') do |config|
  # Your gatewway. In my case its a FritzBox
  gw = '192.168.178.1'

  config.vm.define 'master.k8s', primary: true do |subconfig|
    subconfig.vm.provider 'virtualbox' do |v|
      v.name = 'master.k8s'
    end

    if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'libvirt'
      subconfig.vm.network :public_network, dev: 'eth0', mac: '080027A08AB0'
    else
      subconfig.vm.network :public_network, bridge: 'wlan0', ip: '192.168.178.190'
    end

    subconfig.vm.provision 'shell',
      inline: <<-SHELL
        echo [INIT] Set Hostname
        hostnamectl --static set-hostname master.k8s;
        $(route -n | awk '{ if ($8 == "enp0s3" && $2 != "0.0.0.0") print "route del default gw " $2; }')
        route add default gw "#{gw}" 2>/dev/null || true
      SHELL

    subconfig.vm.provision 'shell',
      inline: <<-SHELL
        ipa=$(ip -br addr | awk '{ if ($2 == "UP" && $3 ~ /192.168.121./ ) print $3 }');

        # kubeadm config print init-defaults --component-configs=KubeletConfiguration > "$KUBEADM_CONFIG"
        # yq -i eval 'select(.nodeRegistration.criSocket) |= .nodeRegistration.criSocket = "unix:///var/run/crio/crio.sock"' "$KUBEADM_CONFIG"
        # yq -i eval 'select(di == 1) |= .cgroupDriver = "systemd"' "$KUBEADM_CONFIG"

        echo [SETUP] kubeadm
        
        yq -i eval "select(.localAPIEndpoint.advertiseAddress) |= .localAPIEndpoint.advertiseAddress = \\"${ipa%/*}\\"" /in/kubeadm.conf.yaml;
        kubeadm init --config /in/kubeadm.conf.yaml | tee /out/master_init;

        echo [SETUP] kubectl config
        cp /etc/kubernetes/admin.conf /out/
        mkdir -p /home/vagrant/.kube
        install -o $(id -u) -g $(id -g) /etc/kubernetes/admin.conf /home/vagrant/.kube/config
        echo "export KUBECONFIG=/home/vagrant/.kube/config" >> /home/vagrant/.profile

        # kubectl taint nodes --all node-role.kubernetes.io/master-

        # curl -s https://api.github.com/repos/heketi/heketi/releases/latest | grep 'browser_download_url' | awk '{print $2}' | grep 'heketi-v.*linux\.amd64' | tr -d '"' | wget -qi - -O - | tar xfzv -
        #wget -qi "https://github.com/heketi/heketi/releases/download/v10.2.0/heketi-v10.2.0.linux.amd64.tar.gz" -O - | tar xfzv -

        #cp heketi/{heketi,heketi-cli} /usr/local/bin

        #groupadd --system heketi
        #useradd -s /sbin/nologin --system -g heketi heketi

        #mkdir -p /var/lib/heketi /etc/heketi /var/log/heketi

        #cp /in/heketi/heketi.json /etc/heketi
        #cp /in/heketi/heketi.service /etc/systemd/system/
        #cp /in/heketi/heketi.env /etc/heketi/
        #chown -R heketi:heketi /var/lib/heketi /var/log/heketi /etc/heketi

        #systemctl daemon-reload
      SHELL
  end

  (1..NODES).each do |i|
    name = "node#{i}.k8s"
    config.vm.define name, autostart: true do |subconfig|
      subconfig.vm.provider 'libvirt' do |v, override|
        (1..DISKS).each do |d|
          disk = "#{name}-#{i}-#{d}.qcow2"
          v.storage :file, path: disk, bus: 'scsi', allow_existing: true, size: 20, serial: disk
        end

        override.trigger.before :"VagrantPlugins::ProviderLibvirt::Action::StartDomain", type: :action do |t|
          t.info = "Replace SCSI controller model for #{name}."
          t.run = { inline: "bash -c 'export LIBVIRT_DEFAULT_URI=#{LIBVIRT_DEFAULT_URI}; virt-xml k8s-playground_#{name} --edit model=lsilogic --controller model=virtio-scsi'" }
          t.exit_codes = [0,1]
        end

        # override.trigger.before :destroy do |t|
        #     t.info = "Removing disks."
        #     t.run = { inline: "bash -c 'export LIBVIRT_DEFAULT_URI=#{LIBVIRT_DEFAULT_URI}; virsh dumpxml k8s-playground_#{name} > /tmp/x; sed -i \"/nvram/d; /loader/d\" /tmp/x; virsh define /tmp/x'" }
        #     t.exit_codes = [0,4]
        # end
      end

      subconfig.vm.provider 'virtualbox' do |v|
        v.name = "node#{i}.k8s"

        (1..DISKS).each do |d|
          disk = "disks/#{v.name}-#{i}-#{d}.vdi"
          unless File.exist?(disk)
            v.customize ['createmedium', 'disk', '--filename', disk, '--variant', 'Standard', '--size', 500 * 1024]
          end
          v.customize ['storageattach', :id,  '--storagectl', 'SATA Controller', '--port', 1+d, '--type', 'hdd', '--nonrotational', 'on', '--medium', disk]
        end
      end

      if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'libvirt'
        subconfig.vm.network :public_network, dev: 'eth0', mac: "080027A08AB#{i}"
      else
        subconfig.vm.network :public_network, bridge: 'wlan0', ip: "192.168.178.19#{i}"
      end
      #Note that sed has to use extra escapes. it actually is: sed 's/\\\s*//g'
      subconfig.vm.provision 'shell',
        run: 'always',
        inline: <<-SHELL
          hostnamectl --static set-hostname "node#{i}.k8s";
          $(route -n | awk '{ if ($8 == "enp0s3" && $2 != "0.0.0.0") print "route del default gw " $2; }');
          route add default gw "#{gw}";
        SHELL

      subconfig.vm.provision 'shell',
        inline: <<-SHELL
          $(tail -n 2 /out/master_init | tr -d '\n' | sed 's/\\\\\s*//g')
        SHELL
    end
  end

  config.vm.box = 'debian/contrib-buster64' if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'virtualbox'

  if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'libvirt'
    # config.vm.box = "debian/buster64"
    config.vm.box = 'debian/bullseye64'
  end

  config.vm.provision 'shell', inline: <<-SHELL
    echo 'Acquire::http { Proxy "http://proxy:3142"; }' | tee -a /etc/apt/apt.conf.d/proxy

    echo [PREFLIGHT] locale
    sed -i '/#\s*en_US\.UTF-8/ s/#//' /etc/locale.gen
    locale-gen --purge en_US.UTF-8
    update-locale LC_ALL=en_US.UTF-8
    update-locale LANG=en_US.UTF-8

    echo [PREFLIGHT] apt
    apt-get update && apt-get -y install gnupg2 apt-transport-https ca-certificates curl gnupg-agent software-properties-common net-tools kubetail git archivemount moreutils
    apt-get -y install golang libseccomp2

    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /etc/apt/trusted.gpg.d/google.gpg add -;
    echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list;
    curl -fsSL "https://baltocdn.com/helm/signing.asc" | apt-key add -
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" > /etc/apt/sources.list.d/helm-stable-debian.list

    apt-get update && apt-get install -y kubelet kubeadm kubectl kubernetes-cni helm ceph ipset ipvsadm

    export OS='Debian_Testing'
    export VERSION=$(apt list kubectl 2>/dev/null | tail -n 1 | awk '{print $2}')

    curl -fsSL "https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:${VERSION%.*}/$OS/Release.key" | apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${VERSION%.*}/$OS/ /" > /etc/apt/sources.list.d/cri-o_$VERSION.list
    curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key" | apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/libcontainers.list


    echo [PREFLIGHT] hosts
    #IPs here only needed when there is no DHCP
    echo 192.168.178.210  master.k8s >> /etc/hosts;
    for i in $(seq 1 2); do
        echo 192.168.178.21${i}  node${i}.k8s >> /etc/hosts;
    done

    echo [PREFLIGHT] kernel mods
    echo "br_netfilter
    overlay
    dm_snapshot
    dm_mirror
    dm_thin_pool" >> /etc/modules-load.d/k8s.conf
    for i in br_netfilter overlay dm_snapshot dm_mirror dm_thin_pool; do
        modprobe $i
    done

    echo [PREFLIGHT] net settings
    echo "net.bridge.bridge-nf-call-ip6tables = 1
		net.ipv6.conf.all.disable_ipv6 = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
    sysctl --system

    echo [PREFLIGHT] swap
    swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab;

    echo [PREFLIGHT] cri-o
    apt-get update && apt-get -y install cri-o cri-o-runc;
    systemctl daemon-reload
    systemctl enable crio --now

    echo '[[registry]]
    prefix = "docker.io"
    insecure = true
    location = "build:443/proxy-cache/"
    ' >> /etc/containers/registries.conf

    echo '[[registry]]
    prefix = "k8s.gcr.io"
    insecure = true
    location = "build:443/k8s.gcr.io/"
    ' >> /etc/containers/registries.conf

    echo '[[registry]]
    prefix = "quay.io"
    insecure = true
    location = "build:443/quay.io/"
    ' >> /etc/containers/registries.conf

    echo '[[registry]]
    insecure = true
    location = "build:443"
    ' >> /etc/containers/registries.conf

    kill -1 $(pgrep crio)

    echo [PREFLIGHT] install packages
#   apt-get install -y glusterfs-client glusterfs-server
#   systemctl enable --now glusterd.service

    go get -u github.com/mikefarah/yq/
    install ${HOME}/go/bin/yq /usr/local/bin/
  SHELL

  if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'virtualbox'
    config.vm.synced_folder './out', '/out'
    config.vm.synced_folder './in', '/in'
    config.vm.synced_folder './keys', '/keys'
    config.vm.synced_folder '.', '/vagrant', disabled: true
  end

  config.ssh.forward_agent = true
  config.ssh.keep_alive = true

  if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'libvirt'
    config.vm.synced_folder './out', '/out', type: 'nfs', nfs_version: 4, nfs_udp: false
    config.vm.synced_folder './in', '/in', type: 'nfs', nfs_version: 4, nfs_udp: false
    config.vm.synced_folder './keys', '/keys', type: 'nfs', nfs_version: 4, nfs_udp: false
    config.vm.synced_folder '.', '/vagrant', disabled: true
  end

  config.vm.provider 'libvirt' do |v|
    v.storage_pool_name = ENV['POOL_NAME']
    # v.storage_pool_path = 'disks'
    v.disk_bus = 'scsi'
    v.disk_device = 'sda'
    v.machine_type = 'q35'
    v.machine_arch = 'x86_64'
    v.memory = 4096
    v.cpu_mode = 'host-passthrough'
    v.cpus = 4
    v.connect_via_ssh = false
    v.driver = 'kvm'
    v.uri = 'qemu:///system'
    # v.loader = '/usr/share/OVMF/OVMF_CODE_4M.fd'
    # v.nvram = '/var/lib/libvirt/qemu/nvram/bcrm_test_efi_VARS.fd'
    v.suspend_mode = 'managedsave'
  end

  config.vm.provider 'virtualbox' do |v, override|
    v.gui = false
    v.memory = 2048
    v.cpus = 2

    override.trigger.before :all do |t|
      t.info = 'Changing machine folder.'
      t.run = { inline: "bash -c 'VBoxManage setproperty machinefolder $(pwd)/vm'" }
    end

    override.trigger.after :all do |t|
      t.info = 'Changing machine folder back to default.'
      t.run = { inline: "bash -c 'VBoxManage setproperty machinefolder default'" }
    end
  end
end
