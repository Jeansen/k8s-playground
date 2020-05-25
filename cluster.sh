#!/usr/bin/env bash

vagrant up --no-provision
vagrant provision
sleep 10
#weavernet
vagrant ssh master.k8s  -c 'kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d "\n")"'

#Dashboard
vagrant ssh master.k8s  -c 'kubectl apply -f /in/dashboard/admin_user.yaml'
vagrant ssh master.k8s  -c 'kubectl apply -f /in/dashboard/dashboard_user.yaml'
vagrant ssh master.k8s  -c 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml'

#Ingress LoadBalancer
vagrant ssh master.k8s  -c 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/cloud/deploy.yaml'

#metalLAB
vagrant ssh master.k8s  -c 'kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml'
vagrant ssh master.k8s  -c 'kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml'
vagrant ssh master.k8s  -c 'kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"'
vagrant ssh master.k8s  -c 'kubectl apply -f /in/metallab.yaml'

#kubectl
vagrant ssh master.k8s  -c "kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}') > /out/dashboard_secret"
vagrant ssh master.k8s  -c 'sudo cp /etc/kubernetes/admin.conf /out/'

#Setup heketi
vagrant ssh master.k8s  -c 'sudo systemctl enable --now heketi.service'
vagrant ssh master.k8s  -c 'sudo heketi-cli topology load --user admin --secret "My Secret"  --json=/in/heketi/topology_virtualbox.json'

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
