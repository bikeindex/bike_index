# Pin npm packages by running ./bin/importmap

# Nothing here is CDN-pinned. The vendor/javascript files are self-contained bundles,
# each carrying its own re-generation command in its header. REMEMBER TO ADD the host to
# content_security_policy.rb if a pin ever goes back to a CDN.

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
# preload: application.js imports this at the top level, so fetching it gates every
# Stimulus controller connecting.
pin "@bikeindex/time-localizer", to: "@bikeindex--time-localizer.js", preload: true
pin "@floating-ui/dom", to: "@floating-ui--dom.js"
# preload: false so a component rendered on a handful of admin pages doesn't fetch 10KB
# on every page -- the controller import()s them for the same reason.
pin "highlight.js/lib/core", to: "highlight.js--core.js", preload: false
pin "highlight.js/lib/languages/json", to: "highlight.js--json.js", preload: false
# preload: false because application.js only import()s it when the page carries an api key
pin "@honeybadger-io/js", to: "@honeybadger-io--js.js", preload: false

# From the chartkick gem's vendor/assets, which its engine adds to assets.precompile.
# preload: false because they are 180KB gzipped that only a page with a chart on it
# should pay for -- ui--chart import()s them when one connects.
pin "chartkick", to: "chartkick.js", preload: false
pin "Chart.bundle", to: "Chart.bundle.js", preload: false

# Our javascript!
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/components", under: "components"
pin_all_from "app/javascript/utils", under: "utils", to: "utils"

# Lexxy rich text editor (Action Text). Assets served by the lexxy/activestorage gems.
pin "lexxy", to: "lexxy.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
