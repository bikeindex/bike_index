# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "2.0"

# Pin the Sprockets manifest to a fixed filename. Sprockets otherwise names it
# .sprockets-manifest-<random>.json, and Kamal bridges assets across deploys with
# `cp -n` (no-clobber), so stale manifests pile up in the shared asset volume and a
# boot can resolve through an old one -- serving outdated digests (a relative import
# then 404s). A fixed name keeps the current deploy's manifest authoritative. Must be
# unconditional so precompile (any RAILS_ENV) and runtime agree on the filename.
Rails.application.config.assets.manifest = Rails.root.join("public/assets/.sprockets-manifest.json")

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
