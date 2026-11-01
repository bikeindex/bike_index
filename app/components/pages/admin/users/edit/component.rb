# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Edit
        # The admin user edit form. The user's details above it are Pages::Admin::Users::Header.
        class Component < ApplicationComponent
          DARK_MODE_ICONS = {
            "light" => ["icons/sun.svg", "tw:text-yellow-500"],
            "dark" => ["icons/moon.svg", "tw:text-indigo-400"],
            "system" => ["icons/computer.svg", nil]
          }.freeze

          def initialize(user:, display_dev_info: false)
            @user = user
            @display_dev_info = display_dev_info
          end

          private

          # Only offered while there's no reason on record - an existing ban is edited
          # through the user_bans screen
          def ban_fields?
            return false if @user.user_ban&.reason.present?

            @user.build_user_ban if @user.user_ban.blank?
            true
          end

          def dark_mode_entries
            DARK_MODE_ICONS.map do |value, (icon, color)|
              label = tag.span(class: "tw:flex tw:flex-col tw:items-center tw:gap-1 tw:py-1") do
                helpers.inline_svg_tag(icon, class: class_names("tw:size-6", color), aria_hidden: true) + value.humanize
              end
              {value:, label:}
            end
          end

          def user_ban_reason_options
            options_for_select(UserBan.reasons.map { |reason| [UserBan.reason_humanized(reason), reason] })
          end
        end
      end
    end
  end
end
