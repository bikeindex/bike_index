# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Edit
        # The admin user edit form. The user's details above it are Pages::Admin::Users::Show.
        class Component < ApplicationComponent
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

          def user_ban_reason_options
            options_for_select(UserBan.reasons.map { |reason| [UserBan.reason_humanized(reason), reason] })
          end
        end
      end
    end
  end
end
