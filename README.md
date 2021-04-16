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
To prevent potential issues due to usage such versions, the k3d version is predefined.

| k3d-action |   k3d   |           k3s           |
|:----------:|:-------:|:-----------------------:|
| v1.1.0     |  [v3.4.0](https://github.com/rancher/k3d/releases/tag/v3.4.0) | [rancher/k3s:v1.20.2-k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.20.2%2Bk3s1)|
| v1.2.0     |  [v4.2.0](https://github.com/rancher/k3d/releases/tag/v4.2.0) | [rancher/k3s:v1.20.2-k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.20.2%2Bk3s1)|
| v1.3.0     |  [v4.2.0](https://github.com/rancher/k3d/releases/tag/v4.2.0) | [rancher/k3s:v1.20.4-k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.20.4%2Bk3s1)|
| v1.4.0     |  [v4.4.1](https://github.com/rancher/k3d/releases/tag/v4.4.1) | specified by k3d or [set image explicitly](https://hub.docker.com/r/rancher/k3s/tags?page=1&ordering=last_updated)|

From `v1.4.0` would k3d-action users set k3s version explicitly via [configuration](#config-file-support) or 
argument e.g.`--image docker.io/rancher/k3s:v1.20.4-k3s1` otherwise k3d specifies which version will be used. 

For further k3s details see: 
 - docker [rancher/k3s](https://hub.docker.com/r/rancher/k3s/tags?page=2&ordering=last_updated)
 - github [k3s/releases](https://github.com/k3s-io/k3s/releases)

## Single Cluster
Although AbsaOSS/k3d-action strongly supports multi-cluster. Single cluster scenarios are very popular. The minimum single-cluster 
configuration looks like this :
```yaml
      - uses: AbsaOSS/k3d-action@v1.4.0
        name: "Create Single Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: --agents 1
```
k3d creates a cluster with one worker node (with [traefik](https://traefik.io/) and metrics services), one agent and one 
default load-balancer node. In real scenarios you might prefer to do some port mapping and disable default load balancer. 
Such an action would look like this:
```yaml
      - uses: AbsaOSS/k3d-action@v1.4.0
        name: "Create Single Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: >-
            -p "8083:80@agent[0]"
            -p "8443:443@agent[0]"
            -p "5053:53/udp@agent[0]"
            --agents 3
            --no-lb
            --image docker.io/rancher/k3s:v1.20.4-k3s1
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"
```
The created cluster exposes two TCP (`:8083`,`:8443`) and one UDP (`:5053`) ports. The cluster comprises one server, three 
agents and no load balancers. [k3s-server-argument](https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/#k3s-server-cli-help) 
disable default traefik and metrics.

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Single+cluster+on+default+network%22), 
[Source](./.github/workflows/single-cluster.yaml)

### Config file support
From v1.2.0 you can configure action via config files or mix arguments together with config files. This setup is useful when 
you want to share the configuration for local testing and testing within k3d-action. 
```yaml
      - uses: ./
        id: single-cluster
        name: "Create single k3d Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: >-
            --agents 1
            --config=<path to config yaml>
```
All you need to do is to place configuration file somewhere into your project. However, keep in mind, that command line
arguments will always take precedence over configuration, so the previous example will result in only one agent, not three as 
configured.
```yaml
apiVersion: k3d.io/v1alpha2
kind: Simple
image: docker.io/rancher/k3s:v1.20.5-k3s1
servers: 1
agents: 3 # The action will overwrite this by 1
ports:
  - port: 0.0.0.0:80:80
    nodeFilters:
      - agent[0]
  - port: 0.0.0.0:443:443
    nodeFilters:
      - agent[0]
  - port: 0.0.0.0:5053:53/udp
    nodeFilters:
      - agent[0]
options:
  k3d:
    wait: true
    timeout: "60s"
    disableLoadbalancer: true
    disableImageVolume: true
  k3s:
    extraServerArgs:
      - --no-deploy=traefik,servicelb,metrics-server
    extraAgentArgs: []
  kubeconfig:
    updateDefaultKubeconfig: true
    switchCurrentContext: true
```
For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Single+cluster+on+default+network+with+config%22),
  [Source action](./.github/workflows/single-cluster-config.yaml), [Source config](./.github/workflows/assets/1.yaml)

## Multi Cluster
AbsaOSS/k3d-action primarily creates clusters in the default bridge-network called  `k3d-action-bridge-network` with 
subnet CIDR `172.16.0.0/24`. To create clusters in the new isolated networks, you must set `network` and `subnet-CIDR` 
manually.

### Multi Cluster on default network
```yaml
      - uses: actions/checkout@v2
      - uses: AbsaOSS/k3d-action@v1.4.0
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
      - uses: AbsaOSS/k3d-action@v1.4.0
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
different ports. Because k3s version is not specified, the clusters will run against latest k3s.

For more details see: 
 - multi-cluster [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+clusters+on+default+network%22), 
[Source](./.github/workflows/multi-cluster.yaml)
 - multi-cluster with config [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+clusters+on+default+network+with+config%22),
   [Source action](./.github/workflows/multi-cluster-config.yaml), [Source config1](./.github/workflows/assets/1.yaml), [Source config2](./.github/workflows/assets/2.yaml)
   
### Multi Cluster on isolated networks
```yaml
      - uses: AbsaOSS/k3d-action@v1.4.0
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

      - uses: AbsaOSS/k3d-action@v1.4.0
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
      - uses: AbsaOSS/k3d-action@v1.4.0
        name: "Create 1st Cluster in 172.20.0.0/24"
        with:
          cluster-name: "test-cluster-1-a"
          network: "nw01"
          subnet-CIDR: "172.20.0.0/24"
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - uses: AbsaOSS/k3d-action@v1.4.0
        name: "Create 2nd Cluster in 172.20.0.0/24"
        with:
          cluster-name: "test-cluster-2-a"
          network: "nw01"
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - uses: AbsaOSS/k3d-action@v1.4.0
        name: "Create 1st Cluster in 172.20.1.0/24"
        with:
          cluster-name: "test-cluster-1-b"
          network: "nw02"
          subnet-CIDR: "172.20.1.0/24"
          args: >-
            --agents 1
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"

      - uses: AbsaOSS/k3d-action@v1.4.0
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
Instead, you can import the image directly into the created cluster:
```shell
docker build . -t <repository>:<semver>
k3d image import <repository>:<semver> -c <cluster-name>
```
Example below demonstrates how to interact with imported docker registry:
```yaml
    steps:
      - uses: actions/checkout@v2
      - uses: AbsaOSS/k3d-action@v1.4.0
        id: single-cluster
        name: "Create single k3d Cluster with imported Registry"
        with:
          cluster-name: test-cluster-1
          args: >-
            --agents 3
            --no-lb
            --k3s-server-arg "--no-deploy=traefik,servicelb,metrics-server"
      - name: "Docker repo demo"
        run: |
          docker build . -t myproj/demo:v1.0.0
          k3d image import myproj/demo:v1.0.0 -c test-cluster-1 --verbose
          kubectl apply -f pod.yaml

# pod.yaml
#
# apiVersion: v1
# kind: Pod
# metadata:
#   name: test-pod
# spec:
#   containers:
#   - name: demo-app
#     image: myproj/demo:v1.0.0
```

For further details see: 
 - shared registry [Demo](https://github.com/AbsaOSS/k3d-action/actions/workflows/single-cluster-import-registry.yaml), 
[Source](./.github/workflows/single-cluster-import-registry.yaml)
