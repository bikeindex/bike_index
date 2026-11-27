# frozen_string_literal: true

module Pages
  module Admin
    module BugReports
      module EmailForm
        # Template Dependency: UI::Card::Component
        # Emails the senders of bug reports. Given a bug_report it's a form of its own for that one;
        # without, it's the table's card that admin--bug-report-email opens, sending the table form's checked rows
        class Component < ApplicationComponent
          BANNED_TEXT = "You are messaging a banned user - they will not receive the message"

          def initialize(bug_report: nil)
            @bug_report = bug_report
          end

          private

          def banned_alert
            return if @bug_report && !@bug_report.sender_email_banned?

            alert = render(UI::Alerts::Base::Component.new(kind: :error, margin_classes: "tw:mb-3", text: BANNED_TEXT))
            return alert if @bug_report

            # Shown while a checked row's checkbox carries data-email-banned
            tag.div(alert, class: "tw:hidden", data: {"admin--bug-report-email-target": "bannedAlert"})
          end

          def title = @bug_report ? "Email sender" : "Email selected senders"

          def table_form_id = (Pages::Admin::BugReports::Table::Component::FORM_ID unless @bug_report)

          def card_data
            data = {controller: "form-persist", "form-persist-key-value": "admin-bug-report-email-#{@bug_report&.id || "selected"}",
                    action: "input->form-persist#save"}
            @bug_report ? data : data.merge("admin--bug-report-email-target": "panel")
          end

          def card_classes
            "#{UI::Card::Component::BASE_CLASSES} tw:rounded-lg tw:p-4 #{"tw:hidden tw:mb-4 tw:ml-auto tw:max-w-3xl" unless @bug_report}"
          end
        end
      end
    end
  end
end
