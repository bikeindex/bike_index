# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::VehicleThumbnail::Component, type: :component do
  let(:options) { {bike:, current_user:, skip_cache:} }
  let(:skip_cache) { false }
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { User.new }

  it "renders" do
    expect(component).to be_present
    expect(component).to have_content bike.mnfg_name
    expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")

    expect(component).to_not have_text(serial.upcase)
    expect(instance.instance_variable_get(:@is_cached)).to be_true
  end
end
