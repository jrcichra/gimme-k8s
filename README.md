# gimme-k8s
Try out Kubernetes with just a docker installation (uses KinD)

## Usage
+ `git clone https://github.com/jrcichra/gimme-k8s`
+ `cd gimme-k8s`
+ `make`

[![asciicast](https://asciinema.org/a/ZxN0026uhyQYPUopBN1tbfrRH.svg)](https://asciinema.org/a/ZxN0026uhyQYPUopBN1tbfrRH)
Software you need for this project:
+ Docker
+ Bash shell for scripts
+ jq

This repo will get you a KinD cluster running a Kubernetes dashboard you can explore with full permissions

You can use ./kubectl to control your cluster

This line will move it into a place where you can execute it from anywhere - `sudo cp ./kubectl /usr/local/bin`
