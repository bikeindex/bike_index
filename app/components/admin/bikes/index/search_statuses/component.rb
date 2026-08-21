# frozen_string_literal: true

module Admin
  module Bikes
    module Index
      module SearchStatuses
        # The "include bikes that are:" checkboxes inside the bikes index search form.
        # Admin::Bikes::Index::Filters renders the trigger that opens it.
        class Component < ApplicationComponent
          # The statuses with no "only" variant, in the order the left column lists them
          PLAIN_STATUSES = {"stolen" => "Stolen", "with_owner" => nil, "abandoned" => "Abandoned",
                            "impounded" => "Impounded",
                            "unregistered_parking_notification" => "Parking Notifications"}.freeze

          # Each of these can be searched on its own, which is a status of its own
          ONLY_STATUSES = {"deleted" => "Deleted", "spam" => "Likely Spam",
                           "example" => "Test / Example"}.freeze

          def initialize(index:, searched_statuses:, default_statuses: [], not_default_statuses: false,
            display_dev_info: false, spam_by_su_option: false)
            @index = index
            @searched_statuses = searched_statuses
            @default_statuses = default_statuses
            @not_default_statuses = not_default_statuses
            @display_dev_info = display_dev_info
            @spam_by_su_option = spam_by_su_option
          end

          private

          def searched?(status) = @searched_statuses.include?(status)

          def only?(status) = searched?("#{status}_only")

          def only_path(status)
            url_for(@index.sortable_search_params.merge("search_status_#{status}": nil,
              "search_status_#{status}_only": true))
          end

          # Every search_status_* param dropped at once is what returns to the default set
          def reset_path
            status_keys = @index.sortable_search_params.keys.select { it.start_with?("search_status") }
            url_for(@index.sortable_search_params.merge(status_keys.index_with(nil)))
          end

          def spam_note?
            @spam_by_su_option && @display_dev_info && @default_statuses.include?("spam")
          end

          def with_owner_label
            safe_join(["With owner", tag.small("(not stolen)", class: "twless-strong")], " ")
          end
        end
      end
    end
  end
end
