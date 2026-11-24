# frozen_string_literal: true

module Atoms
  module Admin
    module Badges
      module BugReportTag
        class ComponentPreview < ApplicationComponentPreview
          def default
            render_with_template(template: "atoms/admin/badges/bug_report_tag/component_preview/default",
              locals: {tags: %w[ask_sign_in_help ask_stolen_bike area_emails area_registration bug spam feedback
                auto_replies bike_index_notification parking search]})
          end
        end
      end
    end
  end
end
