# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      # The catalog search and comparison, rendered in the browser from the published catalog.
      # The page is a <template> bikebook--page fills in from the URL and the catalog,
      # and renders again for each pick and history step
      class Component < ApplicationComponent
        def initialize(manifest_url:, standard_wheel_sizes:)
          @manifest_url = manifest_url
          @standard_wheel_sizes = standard_wheel_sizes
        end
      end
    end
  end
end
