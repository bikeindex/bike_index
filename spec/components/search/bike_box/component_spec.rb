# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::BikeBox::Component, type: :component do
  let(:options) { {bike:, current_user:} }
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:bike) { Bike.new }
  let(:current_user) { User.new }

  it "renders" do
    expect(component).to be_present
  end
end
