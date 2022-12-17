# AbsaOSS/k3d-action

A GitHub Action to run lightweight ephemeral Kubernetes clusters during workflow.
Fundamental advantage of this action is a full customization of embedded k3s clusters. In addition, it provides
multi-cluster support.

- [Introduction](#introduction)
- [Getting started](#getting-started)
  - [Inputs](#inputs)
  - [Version mapping and override](#version-mapping-and-override)
- [Single cluster setup](#single-cluster-setup)
- [Multi-cluster setup](#multi-cluster-setup)
- [Config file support](#config-file-support)
- [Private Registry](#private-registry)

## Introduction

Applications running on Kubernetes clusters (microservices, controllers,...) come with their own set of complexities and concerns.
In particular, E2E testing k8s based applications requires new approaches to confirm proper operation and continued
availability under heavy load or in the face of resource failure. **AbsaOSS/k3d-action allows to test the** _overall_ **application
functionality**. For instance, the E2E use-case is [operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) testing
in [AbsaOSS/k8gb](https://github.com/AbsaOSS/k8gb).

<p align="center">
  <a href="https://www.youtube.com/embed/eZcAvTb0rbA" title="Github Actions review and tutorial by #DevOps Toolkit">
    <img src="https://user-images.githubusercontent.com/7195836/118461760-4a558880-b6fe-11eb-9ffc-5a87c87ed543.png">
  </a>
  <i>The full CI/CD pipeline tutorial with k3d-action by <a href="https://github.com/vfarcic">Viktor Farcic</a>.</i>
</p>

## Getting started
AbsaOSS/k3d-action runs [k3d](https://k3d.io/) which is a lightweight wrapper to run [k3s](https://k3s.io/)
(Rancher Lab’s minimal Kubernetes distribution) in containers. Thanks to that, we could spin up the test environment
quickly with minimal memory requirements, which is especially important in multi-cluster environments.

AbsaOSS/k3d-action defines several input attributes and two outputs:

### Inputs
- `cluster-name` (Required) Cluster name.

- `args` (Optional) list of k3d arguments defined by [k3d command tree](https://k3d.io/usage/commands/)

- `k3d-version` (Optional) version of k3d. If not set, default version will be used from the [version mapping table](#version-mapping-and-override).

### Version mapping and override

Implementation of additional features brings complexity and sometimes it may happen that external dependencies get broken.
To prevent potential issues, `k3d` version is fixed according to the mapping below.

| k3d-action |                             k3d                              |
| :--------: | :----------------------------------------------------------: |
|   v1.1.0   | [v3.4.0](https://github.com/rancher/k3d/releases/tag/v3.4.0) |
|   v1.2.0   | [v4.2.0](https://github.com/rancher/k3d/releases/tag/v4.2.0) |
|   v1.3.0   | [v4.2.0](https://github.com/rancher/k3d/releases/tag/v4.2.0) |
|   v1.4.0   | [v4.4.1](https://github.com/rancher/k3d/releases/tag/v4.4.1) |
|   v1.5.0   | [v4.4.7](https://github.com/rancher/k3d/releases/tag/v4.4.7) |
|   v2.0.0   | [v5.1.0](https://github.com/rancher/k3d/releases/tag/v5.1.0) |
|   v2.1.0   | [v5.2.2](https://github.com/rancher/k3d/releases/tag/v5.2.2) |
|   v2.2.0   | [v5.3.0](https://github.com/k3d-io/k3d/releases/tag/v5.3.0)  |
|   v2.3.0   | [v5.4.1](https://github.com/k3d-io/k3d/releases/tag/v5.4.1)  |
|   v2.4.0   | [v5.4.6](https://github.com/k3d-io/k3d/releases/tag/v5.4.6)  |

Users can override the default `k3d` version with the `k3d-version:` action parameter

```yaml
# example
with:
  k3d-version: v5.2.2
```

Users can also override the default `k3s` image version, using `k3d` `--image` argument

```yaml
# example
with:
  args: --image docker.io/rancher/k3s:v1.20.4-k3s1
```

or the `image:` field in the [k3d configuration file](#config-file-support).

Recent `k3s` image versions can be checked on the [k3.io project releases page](https://github.com/k3s-io/k3s/releases).

## Single cluster setup
Although AbsaOSS/k3d-action strongly supports multi-cluster. Single cluster scenarios are very popular. The minimum single-cluster
configuration looks like this :
```yaml
      - uses: AbsaOSS/k3d-action@v2
        name: "Create Single Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: --agents 1
```
k3d creates a cluster with one worker node (with [traefik](https://traefik.io/) and metrics services), one agent and one
default load-balancer node. In real scenarios you might prefer to do some port mapping and disable default load balancer.
Such an action would look like this:
```yaml
      - uses: AbsaOSS/k3d-action@v2
        name: "Create Single Cluster"
        with:
          cluster-name: "test-cluster-1"
          args: >-
            -p "8083:80@agent:0:direct"
            -p "8443:443@agent:0:direct"
            -p "5053:53/udp@agent:0:direct"
            --agents 3
            --no-lb
            --image docker.io/rancher/k3s:v1.20.4-k3s1
            --k3s-arg "--no-deploy=traefik,servicelb,metrics-server@server:*"
```
The created cluster exposes two TCP (`:8083`,`:8443`) and one UDP (`:5053`) ports. The cluster comprises one server, three
agents and no load balancers. [k3s-server-argument](https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/#k3s-server-cli-help)
disable default traefik and metrics.

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Single+cluster+on+default+network%22),
[Source](./.github/workflows/single-cluster.yaml)

## Multi-cluster setup
k3d creates a bridge-network for each separate cluster or attaches the created cluster to an
existing network.

When you create a cluster named `test-cluster-1`, k3d will automatically create a network
named `k3d-test-cluster-1` with the range `172.18.0.0/16`. When you create a second cluster
`test-cluster-2`, k3d automatically creates a network named `k3d-test-cluster-2` with a
range of `172.19.0.0/16`. Other clusters will have ranges `172.20.0.0/16`,`172.21.0.0/16` etc.

The following example creates a total of four clusters, the first two are created on
the network `nw01, 172.18.0.0/16`, the next two clusters are created on the network
`nw02, 172.19.0.0/16`.

```yaml
      - uses: AbsaOSS/k3d-action@v2
        name: "Create 1st Cluster in 172.18.0.0/16"
        with:
          cluster-name: "test-cluster-1"
          args: >-
            -p "80:80@agent:0:direct"
            -p "443:443@agent:0:direct"
            -p "5053:53/udp@agent:0:direct"
            --agents 3
            --no-lb
            --k3s-arg "--no-deploy=traefik,servicelb,metrics-server@server:*"
            --network "nw01"

      - uses: AbsaOSS/k3d-action@v2
        name: "Create 2nd Cluster in 172.18.0.0/16"
        with:
          cluster-name: "test-cluster-2"
          args: >-
            -p "81:80@agent:0:direct"
            -p "444:443@agent:0:direct"
            -p "5054:53/udp@agent:0:direct"
            --agents 3
            --no-lb
            --k3s-arg "--no-deploy=traefik,servicelb,metrics-server@server:*"
            --network "nw01"

      - uses: AbsaOSS/k3d-action@v2
          name: "Create 1st Cluster in 172.19.0.0/16"
          with:
            cluster-name: "test-cluster-3"
            args: >-
              -p "82:80@agent:0:direct"
              -p "445:443@agent:0:direct"
              -p "5055:53/udp@agent:0:direct"
              --agents 3
              --no-lb
              --k3s-arg "--no-deploy=traefik,servicelb,metrics-server@server:*"
              --network "nw02"

      - uses: AbsaOSS/k3d-action@v2
        name: "Create 2nd Cluster in 172.19.0.0/16"
        with:
          cluster-name: "test-cluster-4"
          args: >-
            -p "83:80@agent:0:direct"
            -p "446:443@agent:0:direct"
            -p "5056:53/udp@agent:0:direct"
            --agents 3
            --no-lb
            --k3s-arg "--no-deploy=traefik,servicelb,metrics-server@server:*"
            --network "nw02"
```
AbsaOSS/k3d-action creates four identical clusters in two different bridge networks.

For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Multi+cluster%3B+two+pairs+of+clusters+on+two+isolated+networks%22),
[Source](./.github/workflows/multi-cluster-two-piars.yaml)

## Config file support
From v1.2.0 you can configure action via config files or mix arguments together with config files. This setup is useful when
you want to share the configuration for local testing and testing within k3d-action.
```yaml
      - uses: ./
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
apiVersion: k3d.io/v1alpha3
kind: Simple
image: docker.io/rancher/k3s:v1.20.5-k3s1
servers: 1
agents: 3 # The action will overwrite this by 1
ports:
  - port: 0.0.0.0:80:80
    nodeFilters:
      - agent:0:direct
  - port: 0.0.0.0:443:443
    nodeFilters:
      - agent:0:direct
  - port: 0.0.0.0:5053:53/udp
    nodeFilters:
      - agent:0:direct
options:
  k3d:
    wait: true
    timeout: "60s"
    disableLoadbalancer: true
  k3s:
    extraArgs:
      - arg: --no-deploy=traefik,servicelb,metrics-server
        nodeFilters:
          - server:*
  kubeconfig:
    updateDefaultKubeconfig: true
    switchCurrentContext: true
```
For more details see: [Demo](https://github.com/AbsaOSS/k3d-action/actions?query=workflow%3A%22Single+cluster+on+default+network+with+config%22),
[Source action](./.github/workflows/single-cluster-config.yaml), [Source config](./.github/workflows/assets/1.yaml)

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
      - uses: AbsaOSS/k3d-action@v2
        name: "Create single k3d Cluster with imported Registry"
        with:
          cluster-name: test-cluster-1
          args: >-
            --agents 3
            --no-lb
            --k3s-arg "--no-deploy=traefik,servicelb,metrics-server@server:*"
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
