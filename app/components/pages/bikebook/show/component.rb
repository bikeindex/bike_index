# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      # The catalog search and comparison, rendered in the browser from the published catalog.
      # The page is a <template> bikebook--page fills in from the URL and the catalog,
      # and renders again for each pick and history step
      class Component < ApplicationComponent
        DONATE_DISMISSED_COOKIE = "bikebook_donate_dismissed"
        MODELS_COUNT = 70_000

        def initialize(manifest_url:, donate_dismissed: false)
          @manifest_url = manifest_url
          @donate_dismissed = donate_dismissed
        end
      end
    end
  end
end
