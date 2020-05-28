# k8s-playground

This repository represents my personal kubernetes playground. I publish it here in the hope that it might be of use to  anyone (like me) who would like to have a custom local cluster that one can toy with.

# Before you start

You should have some basic knowledge of Vagrant and Kubernetes. 

Make sure you have the following tools installed:

- Vagrant 2.2.7 (because of [this regression bug](https://github.com/hashicorp/vagrant/issues/11599) in the latest version)
- Virtual Box 6.1
- kubenetes client (kubectl)

Please have a look at the `Vagrantfile` and `cluster.sh` from within the repository folder. You might want to change the IP addresses and gateway to reflect you local settings.

You should also make sure you have sufficient free space on your disk, at least 20GiB. To avoid swapping, you should also have at least 16GiB of RAM installed.

# Setup

When you are all set, execute `cluster.sh`. The provisioning will take some time. I suggest you get a coffee!

In case you did not change anything, `cluster.sh` will call vagrant which in turn will execute the `Vagrantfile` and create 3 virtual machines: a master and 2 nodes. Every node will have 8 disks attached. These will be used for glusterFS (heketi). Every node will be public, so you can use `kubectl` directly from your local host without having to first create a tunnel to one of the virtual machines.

When you get back the shell prompt, the `out` folder will contain the following files

Now, you have to prepare the context for `kubectl`:

    cp out/admin.conf `~/.kube/admin.conf` 
    export KUBECONFIG=${HOME}/.kube/admin.conf
    
Now see if you can access the cluster with `kubectl`:

    kubectl cluster-info 

# Project structure

The `in` folder contains files needed during provisioning.

When the provision phase passed successfully, the `out` folder will contain the following files:

- admin.conf (Kubernetes context, see previous section)
- dashboard_secret (contains the token to access the Kubernetes Dashboard)
- master_init (Only needed during provisioning, can be ignored)

The `disk` folder will contain all additional  disks created for all nodes and the `vm` folder will contain all the VMs.

The `keys` folder contains the "insecure" default vagrant keys (currently only needed for heketi)


# Custom settings

If you decide to use a different Vagrant box, I suggest you install the `vagrant-vbguest` plugin:

    vagrant plugin install vagrant-vbguest
    
But this will delay the initial creation of the cluster tremendously! 


# Dashboard

The Kubernetes Dashboard is already provisioned and ready to use. All you need is [a token](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md).

You'll find that token at the top of `out/dashboard_secret`. Then `Name:` should start with `default`. Here is an example:

    Name:         default-token-wjsdx
    Namespace:    kubernetes-dashboard
    Labels:       <none>
    Annotations:  kubernetes.io/service-account.name: default
                  kubernetes.io/service-account.uid: ae77d561-9530-4cae-ade5-a973f66a574b
    
    Type:  kubernetes.io/service-account-token
    
    Data
    ====
    ca.crt:     1025 bytes
    namespace:  20 bytes
    token:      eyJhbGciOiJSUzI1NiIsImtpZCI6Il9zWm93XzhzOUloTFJ1d3FiQVpfWElNRUJDMHBXQ3NicERDSWRqSGxJNlkifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkZWZhdWx0LXRva2VuLXdqc2R4Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJhZTc3ZDU2MS05NTMwLTRjYWUtYWRlNS1hOTczZjY2YTU3NGIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQ6ZGVmYXVsdCJ9.kDyVpeKjzXfZFYb7gKMpeAjZLwWNZzHWiY1dEVSxNceqw8348tYGgtAGxSPppeeWv7YQyLYWMC9gHVBuAGkqZBK56p9lO33d3zZ0G8M5g2OLZXNHk7FfZLl7DNAF7mc5YCqE3d1La42MsO5m9F95mphoWnDdFsAaEpMiKiuLFmcRdIGkQUGaITS-gBJPomrLHJhIzRdJMzStHk0iWFUGbxWJ0AJx7pyFpYc65baT_wjwCwgNzJ36QlwK62JgY3cVe5D_oVY4VfFDcAIaoViqMkIwZfmzCPW0CbKNdF9IvyC9k4dOkxyUV3zywEBH871S1pGKG4hUxvCXU3p3W8CZDg

Copy the `token:` value and afterwards run the following command:

    kubectl proxy

Kubectl will make Dashboard available at `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`.

Now paste the token into "Enter token field" on the login screen. You should then see the [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/). 

# Weave Scope
To get a visual impression of a clusters network you can utilize [Weave Scope](https://www.weave.works/docs/scope/latest/installing/#k8s)

To use it, run the following command:

    kubectl port-forward -n weave "$(kubectl get -n weave pod --selector=weave-scope-component=app -o jsonpath='{.items..metadata.name}')" 4040

This will make the Weave Scope dashboard available at `http://localhost:4040/`

Here is an image of what the default cluster setup should look like (only nodes).


![Weave Scope cluster nodes][cluster-nodes]

[cluster-nodes]: .assets/cluster.png "Cluster nodes"

