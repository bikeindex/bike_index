# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoadingSpinner::Component, type: :component do
  let(:options) { {text: "Loading results..."} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(component).to be_present
  end
end
