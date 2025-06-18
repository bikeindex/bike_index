# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::KindOption::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {option_kind:, option:, option_text:, is_selected:, button_url:} }
  let(:option_kind) { :stolenness }
  let(:option) { "proximity" }
  let(:option_text) { "Stolen in search area" }
  let(:button_url) { nil }
  let(:is_selected) { false }

  it "renders" do
    expect(component).to be_present
    expect(component).to have_content option_text
  end
end
