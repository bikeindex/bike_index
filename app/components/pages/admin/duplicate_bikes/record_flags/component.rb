# frozen_string_literal: true

module Pages
  module Admin
    module DuplicateBikes
      module RecordFlags
        # Badges for what a record carries that a merge would have to preserve or rule out
        class Component < ApplicationComponent
          def initialize(bike:, review:)
            @bike = bike
            @review = review
          end

          private

          def contacts
            [@review.initial_ownership(@bike), @bike.current_ownership].compact
              .flat_map { [@review.contact_email(it), @review.account_email(it.user_id)] }
          end
        end
      end
    end
  end
end
