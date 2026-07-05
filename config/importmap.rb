# Pin npm packages by running ./bin/importmap

# REMEMBER TO ADD to content_security_policy.rb if using a CDN version

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
# pin "flowbite", to: "https://cdn.jsdelivr.net/npm/flowbite@2.5.2/dist/flowbite.turbo.min.js"
pin "luxon", to: "https://cdn.jsdelivr.net/npm/luxon@3.5.0/build/es6/luxon.js"
pin "@bikeindex/time-localizer", to: "https://cdn.jsdelivr.net/npm/@bikeindex/time-localizer@0.3.0/dist/index.js"
# Vendored (not CDN-pinned): loads on every page via the dropdown/tooltip
# controllers, so we self-host. jsDelivr's +esm splits sub-deps into
# root-absolute /npm/ imports that 404 against our origin; the vendored
# file is esm.sh's self-contained bundle. See the file header to re-generate.
pin "@floating-ui/dom", to: "@floating-ui--dom.js"

# jQuery is required for select2, which is used by search. It should not be used!
# ideally we transition off it soon!
pin "jquery", to: "https://cdn.jsdelivr.net/npm/jquery@3.6.3/dist/jquery.js", preload: true
pin "select2", to: "https://cdn.jsdelivr.net/npm/select2@4.0.8/dist/js/select2.full.min.js"

# Our javascript!
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/components", under: "components"
pin_all_from "app/javascript/utils", under: "utils", to: "utils"

pin "@honeybadger-io/js", to: "https://cdn.jsdelivr.net/npm/@honeybadger-io/js@6.12.3/dist/browser/honeybadger.min.js"

# Lexxy rich text editor (Action Text). Assets served by the lexxy/activestorage gems.
pin "lexxy", to: "lexxy.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
