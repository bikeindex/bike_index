# frozen_string_literal: true

# Shared helper for axe-core accessibility audits in :js system specs.
#
# axe-core runs its audit through Selenium's execute_async_script, bound by the
# WebDriver script timeout (default 30s). On contended CI runners the audit
# intermittently overruns that window -- and capybara-lockstep's instrumentation
# can leave the callback pending -- surfacing as a flaky
# Selenium::WebDriver::Error::ScriptTimeoutError. Disable lockstep just for the
# audit and give it extra headroom; the rest of the example keeps lockstep on.
module AxeAuditHelpers
  SKIPPABLE_AXE_RULES = %w[aria-allowed-role color-contrast heading-order html-has-lang landmark-one-main landmark-unique page-has-heading-one region]
  AXE_SCRIPT_TIMEOUT = 60

  def expect_axe_clean(*extra_skipped_rules)
    Capybara::Lockstep.with_mode(:off) do
      with_axe_script_timeout do
        expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES, *extra_skipped_rules)
      end
    end
  end

  private

  def with_axe_script_timeout
    timeouts = page.driver.browser.manage.timeouts
    original_timeout = timeouts.script_timeout
    timeouts.script_timeout = AXE_SCRIPT_TIMEOUT
    yield
  ensure
    timeouts.script_timeout = original_timeout
  end
end

RSpec.configure do |config|
  config.include AxeAuditHelpers, type: :system
end
