# frozen_string_literal: true

# Accessibility audits for :js system specs, run via axe-core directly on the
# Playwright page.
#
# The Ruby axe gems (axe-core-rspec/api) assume a Selenium driver -- their audit
# calls driver.manage and switches windows, which the Playwright driver doesn't
# support (dequelabs/axe-core-gems#418). Instead we inject axe-core (the npm
# package) and call axe.run() through the raw Playwright page, the way
# @axe-core/playwright does.
module AxeAuditHelpers
  # Rules these audits deliberately don't enforce.
  SKIPPABLE_AXE_RULES = %w[aria-allowed-role color-contrast heading-order html-has-lang landmark-one-main landmark-unique page-has-heading-one region].freeze

  # Read lazily and once (only when an audit runs) so specs that never audit
  # don't require node_modules to be installed.
  def self.axe_source
    @axe_source ||= Rails.root.join("node_modules/axe-core/axe.min.js").read
  end

  def expect_axe_clean(*extra_skipped_rules)
    disabled = (SKIPPABLE_AXE_RULES + extra_skipped_rules.map(&:to_s)).uniq
    violations = run_axe(disabled)
    expect(violations).to be_empty, -> { axe_failure_message(violations) }
  end

  private

  def run_axe(disabled_rules)
    rules = disabled_rules.to_h { |id| [id, {enabled: false}] }
    page.driver.with_playwright_page do |playwright_page|
      unless playwright_page.evaluate("() => typeof window.axe !== 'undefined'")
        playwright_page.add_script_tag(content: axe_source)
      end
      playwright_page.evaluate(<<~JS, arg: {rules:})
        async (options) => (await axe.run(document, options)).violations
      JS
    end
  end

  def axe_source
    AxeAuditHelpers.axe_source
  end

  def axe_failure_message(violations)
    header = "Found #{violations.size} accessibility #{"violation".pluralize(violations.size)}:"
    details = violations.map do |violation|
      targets = violation["nodes"].to_a.flat_map { |node| node["target"] }.join(", ")
      "- #{violation["id"]} (#{violation["impact"]}): #{violation["help"]}\n" \
        "    #{violation["helpUrl"]}\n    nodes: #{targets}"
    end
    [header, *details].join("\n")
  end
end

RSpec.configure do |config|
  config.include AxeAuditHelpers, type: :system
end
