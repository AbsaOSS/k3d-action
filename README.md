# AbsaOSS/k3d-action
A GitHub Action to run lightweight ephemeral Kubernetes clusters during workflow.
Fundamental advantage of this action is a full customization of embedded k3s clusters. In addition, it provides 
a private image registry and multi-cluster support.

- [Introduction](#introduction)
- [Getting started](#getting-started)
- [Single Cluster](#single-cluster)
- [Multi Cluster](#multi-cluster)
    - [Multi Clusters on default network](#multi-cluster-on-default-network)
    - [Multi Cluster on isolated networks](#multi-cluster-on-isolated-networks)
    - [Two pairs of clusters on two isolated networks](#two-pairs-of-clusters-on-two-isolated-networks)
- [Private Registry](#private-registry)
    - [Single Cluster](#single-cluster-with-private-registry)
    - [Multi Cluster](#multi-cluster-with-private-registry)
    - [Custom Private Registry](#using-custom-private-registry)

## Introduction

Applications running on Kubernetes clusters (microservices, controllers,...) come with their own set of complexities and concerns. 
In particular, E2E testing k8s based applications requires new approaches to confirm proper operation and continued 
availability under heavy load or in the face of resource failure. **AbsaOSS/k3d-action allows to test the** _overall_ **application 
functionality**. For instance, the E2E use-case is [operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) testing
 in [AbsaOSS/k8gb](https://github.com/AbsaOSS/k8gb). 

## Getting started
AbsaOSS/k3d-action runs [k3d](https://k3d.io/) which is a lightweight wrapper to run [k3s](https://k3s.io/) 
(Rancher Lab’s minimal Kubernetes distribution) in containers. Thanks to that, we could spin up the test environment 
quickly with minimal memory requirements, which is especially important in multi-cluster environments.

AbsaOSS/k3d-action defines several input attributes and two outputs:

### Inputs
 - `cluster-name` (Required) Cluster name.
 
 - `args` (Optional) list of k3d arguments defined by [k3d command tree](https://k3d.io/usage/commands/)
 
 - `network` (Optional) Cluster network name. AbsaOSS/k3d-action primarily creates clusters in the default bridge-network 
 called  `k3d-action-bridge-network` with subnet CIDR `172.16.0.0/24`. You can leave this field empty until you  need to 
 have a multiple clusters in different subnets. 
 
 - `subnet-CIDR` (Optional) Cluster subnet CIDR. Provide new CIDR only if `network` is defined first time.
 
 - `use-default-registry` (Optional) If `true`, injects private image registry `registry.localhost:5000` into action.

- `registry-port` (Optional) If the default registry is injected into cluster, the port is `5000`.
  You can change it by setting `registry-port`.

### Outputs
 
  - `network` Detected k3s cluster network
  - `subnet-CIDR` Detected k3s subnet CIDR

Output attributes are accessible via `id`, e.g.:
```yaml
 ${{ steps.<id>.outputs.network }} ${{ steps.<id>.outputs.subnet-CIDR }}
```

For more details see: [Multi Cluster on isolated networks](#multi-cluster-on-isolated-networks)

### Version mapping
Implementation of additional features brings complexity and sometimes may happen that extra feature is broken in special cases. 
To prevent potential issues due to usage such versions, the k3d, k3s versions are hard-coded.

| k3d-action |   k3d   |           k3s           |
|:----------:|:-------:|:-----------------------:|
| v1.1.0     |  [v3.4.0](https://github.com/rancher/k3d/releases/tag/v3.4.0) | [rancher/k3s:v1.20.2-k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.20.2%2Bk3s1)|
| v1.2.0     |  [v4.2.0](https://github.com/rancher/k3d/releases/tag/v4.2.0) | [rancher/k3s:v1.20.2-k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.20.2%2Bk3s1)|


## Single Cluster
Although AbsaOSS/k3d-action strongly supports multi-cluster. Single cluster scenarios are very popular. The minimum single-cluster 
configuration looks like this :
```yaml
      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create Single Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: --agents 1
```
k3d creates a cluster with one worker node (with [traefik](https://traefik.io/) and metrics services), one agent and one 
default load-balancer node. In real scenarios you might prefer to do some port mapping and disable default load balancer. 
Such an action would look like this:
```yaml
      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create Single Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: >-
            -p "8083:80@agent[0]"
            -p "8443:443@agent[0]"
            -p "5053:53/udp@agent[0]"
            --agents 3
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"
```
The created cluster exposes two TCP (`:8083`,`:8443`) and one UDP (`:5053`) ports. The cluster comprises one server, three 
agents and no load balancers. [k3s-server-argument](https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/#k3s-server-cli-help) 
disable default traefik and metrics.

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Single+cluster+on+default+network%22), 
[Source](./.github/workflows/single-cluster.yaml)
## Multi Cluster
AbsaOSS/k3d-action primarily creates clusters in the default bridge-network called  `k3d-action-bridge-network` with 
subnet CIDR `172.16.0.0/24`. To create clusters in the new isolated networks, you must set `network` and `subnet-CIDR` 
manually.

### Multi Cluster on default network
```yaml
      - uses: actions/checkout@v2
      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 1st Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: >-
            -p "80:80@agent[0]"
            -p "443:443@agent[0]"
            -p "5053:53/udp@agent[0]"
            --agents 3
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"
      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 2nd Cluster"
        with:
          cluster-name: "test-cluster-2"
          args: >-
            -p "81:80@agent[0]"
            -p "444:443@agent[0]"
            -p "5054:53/udp@agent[0]"
            --agents 3
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"
```
Both clusters comprise one server node and three agents nodes. Because of port collision, each cluster must expose 
different ports.

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+clusters+on+default+network%22), 
[Source](./.github/workflows/multi-cluster.yaml)

### Multi Cluster on isolated networks
```yaml
      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 1st Cluster in 172.20.0.0/24"
        id: test-cluster-1
        with:
          cluster-name: "test-cluster-1"
          network: "nw01"
          subnet-CIDR: "172.20.0.0/24"
          args: >-
            -p "80:80@agent[0]"
            -p "443:443@agent[0]"
            -p "5053:53/udp@agent[0]"
            --agents 3
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 2nd Cluster in 172.20.1.0/24"
        id: test-cluster-2
        with:
          cluster-name: "test-cluster-2"
          network: "nw02"
          subnet-CIDR: "172.20.1.0/24"
          args: >-
            -p "81:80@agent[0]"
            -p "444:443@agent[0]"
            -p "5054:53/udp@agent[0]"
            --agents 3
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - name: Cluster info
        run: |
          echo test-cluster-1: ${{ steps.test-cluster-1.outputs.network }} ${{ steps.test-cluster-1.outputs.subnet-CIDR }}
          echo test-cluster-2: ${{ steps.test-cluster-2.outputs.network }} ${{ steps.test-cluster-2.outputs.subnet-CIDR }}
```
AbsaOSS/k3d-action creates two identical clusters in two different bridge networks. Because optional argument `id` exists, 
we can list the output arguments in the `Cluster Information` step.

output:
```shell script
    test-cluster-1: nw01 172.20.0.0/24
    test-cluster-2: nw02 172.20.1.0/24
```

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+clusters+on+two+isolated+networks%22), 
[Source](./.github/workflows/multi-cluster-on-isolated-networks.yaml)
### Two pairs of clusters on two isolated networks
```yaml
      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 1st Cluster in 172.20.0.0/24"
        with:
          cluster-name: "test-cluster-1-a"
          network: "nw01"
          subnet-CIDR: "172.20.0.0/24"
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 2nd Cluster in 172.20.0.0/24"
        with:
          cluster-name: "test-cluster-2-a"
          network: "nw01"
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 1st Cluster in 172.20.1.0/24"
        with:
          cluster-name: "test-cluster-1-b"
          network: "nw02"
          subnet-CIDR: "172.20.1.0/24"
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 2nd Cluster in 172.20.1.0/24"
        with:
          cluster-name: "test-cluster-2-b"
          network: "nw02"
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"
```
As you can see, `test-cluster-2-a` doesn't specify subnet-CIDR, because it inherits CIDR from 
`test-cluster-1-a`, but network `nw01` is shared. The same for `test-cluster-2-b` and `test-cluster-1-b`.

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+pairs+of+clusters+on+two+isolated+networks%22), 
[Source](./.github/workflows/multi-cluster-two-piars.yaml)
## Private Registry

Before test starts, you need to build your app and install into the cluster. This requires interaction 
with the image registry. Usually you don't want to push a new image into the remote registry for each test. 
AbsaOSS/k3d-action provides private image registry `registry:2`. Registry is by default listening 
on port `5000` with no authentication and TLS. 

Example below demonstrates how to interact with default docker registry: 
```Makefile
	docker build . -t localhost:5000/test:v0.0.1
	docker push localhost:5000/test:v0.0.1
```

### Single Cluster With Private Registry
```yaml
      - uses: AbsaOSS/k3d-action@v1.1.0
        id: single-cluster
        name: "Create single Cluster with Registry"
        with:
          cluster-name: "test-cluster-1"
          use-default-registry: true
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"
```
`use-default-registry: true` is only setting you should be using. AbsaOSS/k3d-action injects default registry 
into the cluster. If the default port `5000` is already occupied, you can change it by setting optional attribute `registry-port`.

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Single+cluster+on+default+network+with+shared+registry%22), 
[Source](./.github/workflows/single-cluster-registry.yaml)

### Multi Cluster With Private Registry
The similar as previous example but injecting default registry into multiple clusters. It should be noted that the registry 
is shared across clusters, so you don't have to push the same image several times. 
```yaml
      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 1st Cluster in 172.20.0.0/24 with Registry"
        with:
          cluster-name: "test-cluster-1-a"
          network: "nw01"
          subnet-CIDR: "172.20.0.0/24"
          use-default-registry: true
          registry-port: 5001
          args: >-
            --agents 1
            --no-lb

      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 2nd Cluster in 172.20.0.0/24 with Registry"
        with:
          cluster-name: "test-cluster-2-a"
          network: "nw01"
          use-default-registry: true
          args: >-
            --agents 1
            --no-lb

      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 1st Cluster in 172.20.1.0/24 with Registry"
        with:
          cluster-name: "test-cluster-1-b"
          network: "nw02"
          subnet-CIDR: "172.20.1.0/24"
          args: >-
            --agents 1
            --no-lb

      - uses: AbsaOSS/k3d-action@v1.1.0
        name: "Create 2nd Cluster in 172.20.1.0/24 with Registry"
        with:
          cluster-name: "test-cluster-2-b"
          network: "nw02"
          args: >-
            --agents 1
            --no-lb
```
For more details see: 
 - shared registry [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+pairs+of+clusters+on+two+isolated+networks+with+shared+registry%22), 
[Source](./.github/workflows/multi-cluster-two-piars-registry-shared.yaml)
- isolated registries (each network has own registry) [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+pairs+of+clusters+on+two+isolated+networks+with+registry%22),
  [Source](./.github/workflows/multi-cluster-two-piars-registry.yaml)
