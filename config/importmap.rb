# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
# pin "flowbite", to: "https://cdn.jsdelivr.net/npm/flowbite@2.5.2/dist/flowbite.turbo.min.js"
pin "luxon", to: "https://cdn.jsdelivr.net/npm/luxon@3.5.0/build/es6/luxon.js"

# jQuery is required for select2, which is used by search. It should not be used!
# ideally we transition off it soon!
pin "jquery", to: "https://cdn.jsdelivr.net/npm/jquery@3.6.3/dist/jquery.js", preload: true
pin "select2", to: "https://cdn.jsdelivr.net/npm/select2@4.0.8/dist/js/select2.full.min.js"

# Our javascript!
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/components", under: "components"
pin_all_from "app/javascript/utils", under: "utils", to: "utils"
# pin "utils/collapse_utils", to: "utils/collapse_utils.js"
