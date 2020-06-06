# flux-get-started

[![CircleCI](https://circleci.com/gh/fluxcd/flux-get-started.svg?style=svg)](https://circleci.com/gh/fluxcd/flux-get-started)

We published a step-by-step run-through on how to use Flux and Helm Operator [over
here](https://github.com/fluxcd/flux/blob/master/docs/tutorials/get-started-helm.md).

## Workloads

[podinfo](https://github.com/stefanprodan/podinfo)
* Kubernetes deployment, ClusterIP service and Horizontal Pod Autoscaler
* init container automated image updates (regular expression filter)
* container automated image updates (semantic versioning filter)

## Helm Releases

Mongodb
* Source: Helm repository (stable)
* Kubernetes deployment
* automated image updates (semantic versioning filter)

Redis
* Source: Helm repository (stable)
* Kubernetes stateful set 
* locked automated image updates (semantic versioning filter)

Ghost
* Source: Git repository
* disabled automated image updates (glob filter)
* has external dependency - mariadb (stable)

## Manifests Validation

CircleCI [jobs](./.circleci/config.yml):
* validate Kubernetes manifests with [kubeval](https://github.com/instrumenta/kubeval)
* validate Flux Helm Releases with [hrval](https://github.com/stefanprodan/hrval-action)

### <a name="help"></a>Getting Help

If you have any questions about, feedback for or problems with `flux-get-started`:


- Invite yourself to the <a href="https://slack.cncf.io" target="_blank">CNCF community</a>
  slack and ask a question on the [#flux](https://cloud-native.slack.com/messages/flux/)
  channel.
- To be part of the conversation about Flux's development, join the
  [flux-dev mailing list](https://lists.cncf.io/g/cncf-flux-dev).
- [File an issue.](https://github.com/fluxcd/flux/issues/new)

Your feedback is always welcome!
