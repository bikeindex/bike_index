# frozen_string_literal: true

module Pages
  module Admin
    module BugReports
      module EmailForm
        # Template Dependency: UI::Card::Component
        # Emails the senders of bug reports. Given a bug_report it's a form of its own for that one;
        # without, it sits inside the table's form and sends its checked rows, opening over the table
        class Component < ApplicationComponent
          def initialize(bug_report: nil)
            @bug_report = bug_report
          end

          private

          def storage_key = "admin-bug-report-email-#{@bug_report&.id || "selected"}"

          def content_classes
            return "tw:mt-3" if @bug_report

            "#{UI::Card::Component::BASE_CLASSES} tw:absolute tw:right-0 tw:top-full tw:z-10 tw:mt-2 " \
              "tw:w-[min(32rem,90vw)] tw:rounded-lg tw:p-4 tw:shadow-lg"
          end
        end
      end
    end
  end
end
