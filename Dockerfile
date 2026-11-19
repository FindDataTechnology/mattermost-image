# Upstream image, re-hosted in SEVERAL layers — see README.md for why.
#
# WHY THIS IS NOT `FROM mattermost/...`:
#   The upstream image is ~2.39GB and its content sits in essentially ONE layer
#   (upstream's own Dockerfile does `COPY --from=builder /mattermost /mattermost`
#   in a single step). Pushing a multi-GB layer to hkccr fails with the
#   registry's own `BlobNotFound` — a truncated layer upload, not auth or a
#   missing repo. Proven 2026-11-19: a 3.46MB image pushed to this SAME
#   `fd-web/mattermost` repo succeeded; the 2.39GB one never finished. This
#   estate has hit the same wall before (a 350MB layer had to be split in three
#   for the scraw image).
#
#   So we stage the upstream tree and COPY it in directory-sized chunks. Docker
#   makes one layer per COPY, keeping each upload small enough to complete. The
#   runtime content is unchanged — same binary, same paths, same uid — only the
#   layer boundaries differ.
#
#   Layer sizes (upstream 12.1.0, approximate): bin/ and templates/ are the
#   bulk; the rest are small. Splitting by directory rather than by byte count
#   keeps every layer meaningful and the order deterministic.

FROM mattermost/mattermost-enterprise-edition:12.1.0 AS upstream

# Small, registry-reachable base. alpine is already pinned by node-image-keeper
# on every node, so this adds no new pull dependency to the cluster.
FROM alpine:3.20

# Runtime prerequisites the upstream image carries implicitly (it is built on
# distroless/base + explicit document-processing libs). The server binary is
# statically linked Go, so this list is only what the *file preview* path needs;
# Mattermost itself refuses to start without ca-certificates (TLS) and tzdata
# (scheduled jobs).
RUN apk add --no-cache ca-certificates tzdata libc6-compat

# ── the upstream tree, in directory-sized layers ─────────────────────────────
COPY --from=upstream /mattermost/bin          /mattermost/bin
COPY --from=upstream /mattermost/templates    /mattermost/templates
COPY --from=upstream /mattermost/i18n         /mattermost/i18n
COPY --from=upstream /mattermost/client       /mattermost/client
COPY --from=upstream /mattermost/fonts        /mattermost/fonts
# Everything else (config, plugins, data, logs and any straggler) in one last
# layer — small by construction once the big trees above are out.
COPY --from=upstream /mattermost/             /mattermost/

# Document-preview binaries and their shared libraries (upstream ships these;
# without them, PDF/Word preview silently degrades).
COPY --from=upstream /usr/bin/pdftotext /usr/bin/wvText /usr/bin/wvWare /usr/bin/unrtf /usr/bin/tidy /usr/bin/
COPY --from=upstream /usr/share/wv            /usr/share/wv
COPY --from=upstream /usr/lib/libpoppler.so*  /usr/lib/
COPY --from=upstream /usr/lib/libfreetype.so* /usr/lib/
COPY --from=upstream /usr/lib/libpng.so*      /usr/lib/
COPY --from=upstream /usr/lib/libwv.so*       /usr/lib/
COPY --from=upstream /usr/lib/libtidy.so*     /usr/lib/
COPY --from=upstream /usr/lib/libfontconfig.so* /usr/lib/

# Same runtime contract as upstream.
ENV PATH="/mattermost/bin:${PATH}" \
    MM_SERVICESETTINGS_ENABLELOCALMODE="true" \
    MM_INSTALL_TYPE="docker"

USER 2000:2000
WORKDIR /mattermost
VOLUME ["/mattermost/data", "/mattermost/logs", "/mattermost/config", "/mattermost/plugins", "/mattermost/client/plugins", "/mattermost/bleve-indexes"]
EXPOSE 8065
ENTRYPOINT ["/mattermost/bin/mattermost"]
