# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::HomepageTop::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {} }

  it "renders" do
    expect(component).to be_present
  end
end
