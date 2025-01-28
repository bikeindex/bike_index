# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "flowbite", to: "https://cdn.jsdelivr.net/npm/flowbite@2.5.2/dist/flowbite.turbo.min.js"
pin "luxon", to: "https://cdn.jsdelivr.net/npm/luxon@3.5.0/build/es6/luxon.js"

# Our javascript!
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/components", under: "components"
