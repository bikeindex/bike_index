# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::Threads::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {marketplace_messages:, current_user:} }
  let(:marketplace_messages) { nil }
  let(:current_user) { nil }

  it "renders" do
    expect(component).to be_present
  end
end
