# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module DuplicateGroup
        # The bikes sharing a serial segment, side by side for deciding which registration is
        # the real one: delete the others, or ignore the group if they're all legitimate.
        # bike: the one whose page this is, which gets marked
        class Component < ApplicationComponent
          THUMB_CLASSES = "tw:h-32 tw:w-full tw:rounded-lg tw:border tw:border-gray-200 tw:dark:border-gray-700"

          def initialize(duplicate_group:, bike: nil)
            @duplicate_group = duplicate_group
            @bike = bike
          end

          private

          def bikes
            @duplicate_group.bikes.includes(:current_stolen_record, :creation_organization, :current_ownership).reorder(:created_at)
          end

          def current?(bike) = bike.id == @bike&.id

          def title(bike) = [bike.year, bike.mnfg_name, bike.frame_model].compact_blank.join(" ")

          def card_classes(bike)
            ["tw:flex tw:flex-col tw:gap-3 tw:rounded-xl tw:p-4", UI::Card::Component::BASE_CLASSES,
              ("tw:ring-2 tw:ring-blue-500" if current?(bike))].compact.join(" ")
          end

          def stolen_text(stolen_record)
            [stolen_record.date_stolen&.to_date&.to_fs(:long), stolen_record.formatted_address_string(visible_attribute: :city)]
              .compact_blank.join(" · ")
          end
        end
      end
    end
  end
end
