# Upstream image, re-hosted — see README.md for why this repo exists.
#
# Pinned to a full version, not `latest` and not a floating major: the whole
# point of re-hosting is that a deploy is a decision, not an accident of what
# the mirror happened to cache. Upgrading = edit this line + push (README).
#
# WHY THE ENTERPRISE-EDITION IMAGE AND NOT team-edition:
#   The community `team-edition` image is MIT but has NO OpenID Connect, so it
#   cannot join the platform's unified identity — running it would mean a second
#   account system, which the deployment explicitly rejects.
#   `mattermost-enterprise-edition` runs in "Entry" mode with NO license key and
#   no expiry (upstream: "You are welcome to use the Enterprise Edition of
#   Mattermost free of charge in perpetuity when the subscription features are
#   not enabled by a license key"), and Entry DOES include OIDC.
#   Entry's trade-off is a 10,000-message global history cap — measured and
#   alarmed for by the deployment, and lifted by adding a license key with no
#   data migration.
#
# Do NOT switch this line to team-edition to "get rid of the cap": that trades a
# measured cap for an unusable identity story.
FROM mattermost/mattermost-enterprise-edition:12.1.0
