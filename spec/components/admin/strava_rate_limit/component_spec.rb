# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StravaRateLimit::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {rate_limit_json:} }
  let(:rate_limit_json) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end
