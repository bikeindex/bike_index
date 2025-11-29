# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::ChooseMembership::Component, type: :component do
  let(:options) { {currency: Currency.default} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(component).to be_present
  end
end
