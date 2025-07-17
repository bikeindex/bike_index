# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::ResultViewSelect::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {result_view:} }
  let(:result_view) { nil }

  it "renders" do
    expect(component).to be_present
    expect(component).to have_css "ul"
  end
end
