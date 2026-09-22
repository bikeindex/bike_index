# frozen_string_literal: true

module Pages
  module Org
    module SearchResults
      module BikeCard
        class ComponentPreview < ApplicationComponentPreview
          # @param search_all toggle
          def default(search_all: false)
            organization = Organization.first || Organization.new(name: "Brakebills University", short_name: "Brakebills")
            render_with_template(locals: {organization:, search_all:,
                                          bikes: Pages::SearchResults::BikeBox::ComponentPreview.vehicles})
          end
        end
      end
    end
  end
end
