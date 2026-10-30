# frozen_string_literal: true

module Pages
  module Admin
    module DuplicateBikes
      module RecordDetail
        # A record's initial registration, current ownership and the stored values a merge would keep
        class Component < ApplicationComponent
          def initialize(bike:, review:)
            @bike = bike
            @review = review
          end
        end
      end
    end
  end
end
