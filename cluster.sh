#!/usr/bin/env bash

export _HOME_="$(dirname $(realpath ${BASH_SOURCE[0]}))"
[[ -z ${VAGRANT_HOME// } ]] && export VAGRANT_HOME="$_HOME_/.vagrant.d/"
export VAGRANT_DEFAULT_PROVIDER=libvirt
export LIBVIRT_DEFAULT_URI="qemu:///system" 
export POOL_NAME="k8s"
# export VAGRANT_LOG="debug"

if [[ $VAGRANT_DEFAULT_PROVIDER == libvirt ]] && ! virsh pool-list --all | grep -qE "$POOL_NAME(\s|$)"; then
    [[ -d $_HOME_/disks/ ]] || { echo "$_HOME_/disks/ does not exist" && exit 1; }
    virsh pool-define-as $POOL_NAME dir - - - - $_HOME_/disks/
fi


case "$1" in
'provision')
    vagrant provision
    ;;
'halt')
    vagrant halt
    ;;
'create'|'rebuild')
    sudo systemctl restart nfs-server.service
    virsh pool-start $POOL_NAME 2>/dev/null
    vagrant destroy -f
    vagrant up --no-provision
    vagrant provision
    ;;
'suspend')
    vagrant "$1"
    exit 0
    ;;
'up'|'resume')
    sudo systemctl restart nfs-server.service
    virsh pool-start $POOL_NAME 2>/dev/null
    vagrant "$1"
    exit 0
    ;;
'destroy')
    vagrant destroy -f
    rm -f $_HOME_/disks/*
    virsh pool-refresh $POOL_NAME
    exit 0
    ;;
'ssh')
    vagrant "$@"
    exit 0
    ;;
*)
    echo "<cluser.sh> rebuild|suspend|resume|destroy|up|create"
    exit 1
    ;;
esac


sleep 10
#weavernet
# vagrant ssh master.k8s  -- -t 'sudo ip -s -s neigh flush all'
# vagrant ssh node1.k8s  -- -t 'sudo ip -s -s neigh flush all'
# vagrant ssh node2.k8s  -- -t 'sudo ip -s -s neigh flush all'

#flannel
# vagrant ssh master.k8s  -- -t 'kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'


vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Patch DNS"
kubectl -n kube-system get configmap coredns -o yaml | sed "/forward/ s|/etc/resolv.conf|192.168.178.1:53|" | kubectl apply -f -
kubectl delete pods -n kube-system -l k8s-app=kube-dns'

#weave
vagrant ssh master.k8s  -- -t 'kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d "\n")"'


vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Dashboard"
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard'

vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Rook (Ceph)"
helm repo add rook-release https://charts.rook.io/release
helm repo update
helm install --wait --namespace rook-ceph rook-ceph rook-release/rook-ceph --create-namespace
kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.6.3/cluster/examples/kubernetes/ceph/cluster-test.yaml
kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.6.3/cluster/examples/kubernetes/ceph/csi/rbd/storageclass-test.yaml
kubectl patch storageclass rook-ceph-block -p '"'"'{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'"'"

sleep 5m

vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Remove taints"
kubectl taint nodes --all node-role.kubernetes.io/master-'

vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Prometheus"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/
helm repo update
helm install prometheus prometheus-community/prometheus'

vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Ingress LoadBalancer"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx'
# helm pull ingress-nginx/ingress-nginx
# mkdir mnt 
# archivemount ingress-nginx*.tgz mnt/
# sed "/digest:/d" mnt/ingress-nginx/values.yaml | sponge mnt/ingress-nginx/values.yaml
# umount mnt/
# helm install ingress-nginx ingress-nginx*.tgz

vagrant ssh master.k8s  -- -t 'echo "[SETUP]: metalLAB"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install metallb bitnami/metallb
kubectl apply -f /in/metallab.yaml'

vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Kubectl"
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk "{print \$1}") > /out/dashboard_secret
sudo cp /etc/kubernetes/admin.conf /out/'

#vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Heketi"
#sudo systemctl enable --now heketi.service
#sudo heketi-cli topology load --user admin --secret "My Secret"  --json=/in/heketi/topology_virtualbox.json'

#echo "[SETUP]: Weaver Scope"
#kubectl apply -f "https://cloud.weave.works/k8s/scope.yaml?k8s-version=$(kubectl version | base64 | tr -d "\n")"

vagrant ssh master.k8s  -- -t 'echo "[SETUP]: Metrics Server for HPA"
kubectl apply -f <(curl -fsSL https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.4.3/components.yaml | yq e '"'"'select(.spec.template.spec.containers.[].args) |= .spec.template.spec.containers.[].args += "--kubelet-insecure-tls"'"'"' -)'


# These are commands you'll have to run on the client so you can use kubectl with your custom cluster
#
# mkdir ${HOME}/.kube/
# install out/admin.conf ${HOME}/.kube/
# export KUBECONFIG=${HOME}/.kube/admin.conf

# If you want to persist the settings, put it in your shell's rc file. Example for Bash:
#
# echo "export KUBECONFIG=${HOME}/.kube/admin.conf" >> ${HOME}/.bashrc


# You might also want to use these little helpers ;-)
#
# alias kcd='kubectl config set-context $(kubectl config current-context) --namespace '
# alias k=kubectl
# source <(kubectl completion bash | sed s/kubectl/k/g) #to make sure completion works with the alias 'k'
