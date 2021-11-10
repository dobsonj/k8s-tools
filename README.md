
# k8s-tools

The goal of this repo is to simplify the development and test cycle for kubernetes changes.
Quickly spin up a VM on AWS, or locally via KVM, and run local-up-cluster.
Get started developing and testing kubernetes changes right away, and then optimize your workflow as you go.

## Who is this repo for?

- Kubernetes developers (especially newcomers)
- Anyone who wants to quickly test kubernetes on a single VM

## Prerequisites

In order to follow these instructions, you'll first need the following tools installed on your system:

- terraform (for aws provider)
- vagrant (for kvm provider)
- ansible-playbook

## Providers

### AWS (via terraform / ansible)

#### Init

If you haven't already done so, set up an AWS profile on your system.

```
export AWS_PROFILE=<your_profile_name>
aws configure --profile=$AWS_PROFILE
```

Then initialize terraform for the AWS provider.

```
cd ./providers/aws
terraform init
```

#### Provision

Review the default values in `vars.tf`. Each of these can be overwritten by passing `-var "variable_name=value"` into `terraform apply`.

To provision the instance:

```
terraform apply \
    -var "aws_profile=${AWS_PROFILE}" \
    -var "region=us-east-2" \
    -var "tag_name=${USER}-dev01"
```

This will start provisioning the infrastructure, run an ansible setup script to install the required packages, clone the kubernetes repo, and update some config files on the instance.

When provisioning is complete, you should see a message like this:

```
aws_instance.dev_vm01 (local-exec): Provisioning complete!
aws_instance.dev_vm01 (local-exec): To log into the VM, run:
aws_instance.dev_vm01 (local-exec):   ssh ubuntu@52.14.56.78
aws_instance.dev_vm01 (local-exec): To start kubernetes on the VM, run:
aws_instance.dev_vm01 (local-exec):   sudo su -
aws_instance.dev_vm01 (local-exec):   export AWS_ACCESS_KEY_ID=...
aws_instance.dev_vm01 (local-exec):   export AWS_SECRET_ACCESS_KEY=...
aws_instance.dev_vm01 (local-exec):   local-up-cluster
```

#### Test

SSH into the instance:

```
ssh ubuntu@<public_ip>
```

To start kubernetes, you have to be root:

```
sudo su -
```

Set environment variables for your session with the AWS credentials you used to provision the instance:

```
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

and then run:

```
local-up-cluster
```

When your cluster is ready, you should see a message like this:

```
Local Kubernetes cluster is running. Press Ctrl-C to shut it down.

Logs:
  /tmp/kube-apiserver.log
  /tmp/kube-controller-manager.log

  /tmp/kube-proxy.log
  /tmp/kube-scheduler.log
  /tmp/kubelet.log

To start using your cluster, you can open up another terminal/tab and run:

  export KUBECONFIG=/var/run/kubernetes/admin.kubeconfig
  cluster/kubectl.sh

Alternatively, you can write to the default kubeconfig:

  export KUBERNETES_PROVIDER=local

  cluster/kubectl.sh config set-cluster local --server=https://localhost:6443 --certificate-authority=/var/run/kubernetes/server-ca.crt
  cluster/kubectl.sh config set-credentials myself --client-key=/var/run/kubernetes/client-admin.key --client-certificate=/var/run/kubernetes/client-admin.crt
  cluster/kubectl.sh config set-context local --cluster=local --user=myself
  cluster/kubectl.sh config use-context local
  cluster/kubectl.sh
```

You can now login as root from another terminal, and run:

```
export KUBECONFIG=/var/run/kubernetes/admin.kubeconfig
```

You're ready to start using it! Run `kubectl get nodes` to see the available node.

#### Making code changes

The steps above clone <https://github.com/kubernetes/kubernetes> to `/root/go/src/k8s.io/kubernetes` automatically, and uses the latest version of the `master` branch. `local-up-cluster` is an alias, and it will automatically build kubernetes the first time you run it on the instance.

If you want to test code changes, you can modify the code directly in `/root/go/src/k8s.io/kubernetes` and run `local-up-cluster` again. Or you can pull another remote branch into that clone to test after provisioning has finished.

For more info on the kubernetes development process, refer to <https://github.com/kubernetes/community/blob/master/contributors/devel/README.md>

#### Destroy

Make sure you've pushed any changes you wish to keep to an external repo before destroying the instance!

When you're ready to destroy the instance AND ALL OF ITS DATA:

```
terraform destroy \
    -var "aws_profile=${AWS_PROFILE}" \
    -var "region=us-east-2" \
    -var "tag_name=${USER}-dev01"
```

