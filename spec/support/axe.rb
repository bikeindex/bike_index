# frozen_string_literal: true

# Shared helper for axe-core accessibility audits in :js system specs.
#
# Playwright's page.evaluate has no script timeout (unlike Selenium's 30s cap),
# so the audit runs to completion without the flaky timeout juggling the
# Selenium driver required.
#
# legacy_mode routes the audit through axe-core-api's Capybara-compatible
# execute_async_script path. Its default `runPartial` path drives Selenium
# directly (manage.timeouts, window switching) and isn't supported by the
# Playwright driver.
Axe::Configuration.instance.legacy_mode = true

module AxeAuditHelpers
  SKIPPABLE_AXE_RULES = %w[aria-allowed-role color-contrast heading-order html-has-lang landmark-one-main landmark-unique page-has-heading-one region]

  def expect_axe_clean(*extra_skipped_rules)
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES, *extra_skipped_rules)
  end
end

RSpec.configure do |config|
  config.include AxeAuditHelpers, type: :system
end
