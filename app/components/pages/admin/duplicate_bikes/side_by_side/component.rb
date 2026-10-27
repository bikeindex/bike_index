# frozen_string_literal: true

module Pages
  module Admin
    module DuplicateBikes
      module SideBySide
        # A small group's records in columns, every compared value in a row, rows that differ highlighted.
        # link_params: the page's own params
        class Component < ApplicationComponent
          def initialize(review:, link_params:)
            @review = review
            @link_params = link_params
          end
        end
      end
    end
  end
end
