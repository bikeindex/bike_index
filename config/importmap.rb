# Pin npm packages by running ./bin/importmap

# REMEMBER TO ADD to content_security_policy.rb if using a CDN version

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
# pin "flowbite", to: "https://cdn.jsdelivr.net/npm/flowbite@2.5.2/dist/flowbite.turbo.min.js"
# Vendored and preloaded (not CDN-pinned): application.js imports this at the
# top level, so fetching it gates every Stimulus controller connecting.
# See the file header to re-generate.
pin "@bikeindex/time-localizer", to: "@bikeindex--time-localizer.js", preload: true
# Vendored (not CDN-pinned): loads on every page via the dropdown/tooltip
# controllers, so we self-host. jsDelivr's +esm splits sub-deps into
# root-absolute /npm/ imports that 404 against our origin; the vendored
# file is esm.sh's self-contained bundle. See the file header to re-generate.
pin "@floating-ui/dom", to: "@floating-ui--dom.js"
# Vendored because cdnjs isn't in content_security_policy.rb; see each file's header to
# re-generate. preload: false so a component rendered on a handful of admin pages doesn't
# fetch 10KB on every page -- the controller import()s them for the same reason.
pin "highlight.js/lib/core", to: "highlight.js--core.js", preload: false
pin "highlight.js/lib/languages/json", to: "highlight.js--json.js", preload: false

# jQuery is required for select2, which is used by search. It should not be used!
# ideally we transition off it soon!
pin "jquery", to: "https://cdn.jsdelivr.net/npm/jquery@3.6.3/dist/jquery.js", preload: true
pin "select2", to: "https://cdn.jsdelivr.net/npm/select2@4.0.8/dist/js/select2.full.min.js"

# Our javascript!
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/components", under: "components"
pin_all_from "app/javascript/utils", under: "utils", to: "utils"

# +esm build: the dist/browser UMD bundle's default export is undefined under import(),
# which silently breaks Honeybadger.configure and leaves frontend errors unreported
pin "@honeybadger-io/js", to: "https://cdn.jsdelivr.net/npm/@honeybadger-io/js@6.12.3/+esm"

# Lexxy rich text editor (Action Text). Assets served by the lexxy/activestorage gems.
pin "lexxy", to: "lexxy.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
