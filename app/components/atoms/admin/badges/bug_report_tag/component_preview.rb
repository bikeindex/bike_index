# frozen_string_literal: true

module Atoms
  module Admin
    module Badges
      module BugReportTag
        class ComponentPreview < ApplicationComponentPreview
          def default
            tags = %w[ask_sign_in_help ask_stolen_bike area_emails area_registration bug spam auto_replies
              bike_index_notification parking search]
            safe_join(tags.map { render(Atoms::Admin::Badges::BugReportTag::Component.new(tag: it)) }, " ")
          end
        end
      end
    end
  end
end
