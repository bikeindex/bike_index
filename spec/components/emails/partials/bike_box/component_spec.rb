# frozen_string_literal: true

require "rails_helper"

RSpec.describe Emails::Partials::BikeBox::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {bike:, ownership:, bike_url_path:} }
  let(:bike) { nil }
  let(:ownership) { nil }
  let(:bike_url_path) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end
