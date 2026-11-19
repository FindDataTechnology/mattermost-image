# Mattermost upstream image, re-hosted.

One line, on purpose. This repo exists because the cluster **cannot pull the
upstream image** — not because we want to build anything.

## Why this repo exists

Measured 2026-11-19 on the cheap-ts cluster, four paths, all failed:

| path | result |
|---|---|
| `docker.io/mattermost/mattermost-enterprise-edition:v12.1` | `ETIMEDOUT` (no direct egress) |
| `docker.m.daocloud.io/mattermost/…` | `403 Forbidden` |
| `docker.1ms.run/mattermost/…` | `404 not found` (not cached upstream) |
| node `ImagePullBackOff` on cheap-5/6/8 | same three failures |

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
