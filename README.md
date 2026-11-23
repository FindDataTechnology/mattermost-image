# Mattermost upstream image, re-hosted.

One line, on purpose. This repo exists because the cluster **cannot pull the
upstream image fast enough to be usable** — not because we want to build anything.

## Why this repo exists

Measured 2026-11-19 on the cheap-ts cluster, four paths, all failed:

| path | result |
|---|---|
| `docker.io/mattermost/mattermost-enterprise-edition:v12.1` | `ETIMEDOUT` (no direct egress) |
| `docker.m.daocloud.io/mattermost/…` | `403 Forbidden` |
| `docker.1ms.run/mattermost/…` | `404 not found` (not cached upstream) |
| node `ImagePullBackOff` on the worker nodes | same three failures |

> **2026-11-22 更正：`no direct egress` 这个说法不准确。** 重测发现 docker.io
> **可达，但按体积分档**：
>
> | 镜像 | 结果 |
> |---|---|
> | `library/busybox:1.36`（2.2 MB） | 2 秒拉完 |
> | `library/alpine:3.20` | 节点上已有 |
> | `library/nginx:1.27-alpine` | 73 秒后仍在 `Pulling`，无失败事件 |
> | `mattermost/mattermost-enterprise-edition:v12.1` | 同样卡在 `Pulling` |
>
> 集群里有 19 个容器在跑 docker.io 镜像，都是早期拉下来的小镜像。所以真实约束是
> **跨国带宽**，不是网络不可达。结论文档不变（re-host 仍然必要），但理由要写准：
> 说「不可达」会让下一个人去查网络配置，而该查的是带宽。
>
> 也别指望「等久一点就能拉完」：`ETIMEDOUT` 是 kubelet 的拉取超时，镜像越大越必然
> 触发，且失败后 `ImagePullBackOff` 退避会越拉越长。

So the image has to come from a registry the cluster **can** reach:
`ccr.ccs.tencentyun.com`, fed by the standard publish chain
(GHA → `hkccr` → cheap9 relay → `ccr`).

A hand-`ctr import` onto each node was rejected: it is not reproducible, it
silently breaks when a node joins, and the nightly image GC deletes anything no
container references — after which the job is permanently un-pullable and every
health check still reads green. (That exact failure already happened once:
`node-image-keeper`'s header documents the `alpine/git` loss on 2026-11-14.)

## Upgrading

This is the whole procedure:

1. Change the tag in `Dockerfile` (pin a **specific version**, never `latest`).
2. Push to `main` — the workflow builds, boots the image and probes it before
   pushing anything.
3. Wait for the relay (≤5 min) to land it on `ccr`.
4. Verify from a cluster node — a green workflow is **not** evidence:
   ```
   k3s ctr -n k8s.io images pull ccr.ccs.tencentyun.com/fd-web/mattermost:<tag>
   ```
   Historical precedent for why: the Jenkins `lawcraw` job reported SUCCESS
   three times while producing zero images.
5. Bump the tag in `fd-infra-deploy/all-services/mattermost/03-web.yaml`.

## Licensing

The upstream image is redistributed **unmodified**; no code of ours is in it.

Which upstream image, and why, is documented at the top of `Dockerfile` — short
version: the enterprise-edition image runs as the free "Entry" tier with no
license key, because Entry is the cheapest tier that includes OpenID Connect.
The MIT `team-edition` image is deliberately NOT used: it has no OIDC, so it
could not join the platform's unified identity.
