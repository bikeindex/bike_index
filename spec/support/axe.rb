# frozen_string_literal: true

# Shared helper for axe-core accessibility audits in :js system specs.
#
# capybara-lockstep's page instrumentation intermittently leaves axe-core's
# execute_async_script callback pending, surfacing as a flaky
# Selenium::WebDriver::Error::ScriptTimeoutError. Disable lockstep just for the
# audit; the rest of the example keeps it enabled.
module AxeAuditHelpers
  SKIPPABLE_AXE_RULES = %w[aria-allowed-role color-contrast heading-order html-has-lang landmark-one-main landmark-unique page-has-heading-one region]

  def expect_axe_clean(*extra_skipped_rules)
    Capybara::Lockstep.with_mode(:off) do
      expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES, *extra_skipped_rules)
    end
  end
end

RSpec.configure do |config|
  config.include AxeAuditHelpers, type: :system
end
