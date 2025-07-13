# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::Container::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {vehicles:, component_class:, skip_cache:} }
  let(:vehicles) { nil }
  let(:component_class) { nil }
  let(:skip_cache) { nil }

  it "renders" do
    expect(component).to be_present
  end
end
