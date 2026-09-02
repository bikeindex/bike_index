# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module Summary
        module Recovery
          # How a recovered stolen record was recovered, below Pages::Admin::Bikes::Summary::Theft
          class Component < ApplicationComponent
            def initialize(stolen_record:, display_recovery: false)
              @stolen_record = stolen_record
              @display_recovery = display_recovery
            end

            def render? = @display_recovery && @stolen_record&.recovered?

            private

            def recovering_user_cell
              if @stolen_record.recovering_user.present?
                recovering_user_link
              elsif @stolen_record.pre_recovering_user?
                tag.small("pre-recording of recovering user", class: "twless-strong")
              else
                safe_join([tag.small("No user present"),
                  tag.span("most likely recovered by owner", class: "twless-strong tw:text-sm")], " ")
              end
            end

            def recovering_user_link
              user = @stolen_record.recovering_user
              link = link_to(user.display_name, admin_user_path(user.to_param), class: "twlink")
              return link if @stolen_record.recovering_user_owner?

              safe_join([link, tag.em("not owner!",
                class: "#{UI::Alerts::Base::Component::TEXT_CLASSES[:warning]} tw:text-sm")], " ")
            end
          end
        end
      end
    end
  end
end
