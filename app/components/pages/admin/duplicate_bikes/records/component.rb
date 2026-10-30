# frozen_string_literal: true

module Pages
  module Admin
    module DuplicateBikes
      module Records
        # A duplicate review's records, one row each: what departs from the group's common values,
        # the record's flags and, behind a collapse, its full details. link_params: the page's own params
        class Component < ApplicationComponent
          def initialize(bikes:, review:, link_params:)
            @bikes = bikes
            @review = review
            @link_params = link_params
          end
        end
      end
    end
  end
end
