# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::HomepageTop::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {recoveries_value:, organization_count:, recovery_displays:} }
  let(:recoveries_value) { 11111 }
  let(:organization_count) { nil }
  let(:recovery_displays) { [] }

  it "renders" do
    expect(component).to be_present
    expect(component).to have_css("div")
  end
end
