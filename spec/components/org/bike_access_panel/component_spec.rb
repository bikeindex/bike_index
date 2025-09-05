# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeAccessPanel::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {bike:, organization:, current_user:} }
  let(:bike) { FactoryBot.create(:bike) }
  let(:organization) { current_user.organizations.first }
  let(:current_user) { FactoryBot.create(:organization_user) }

  it "renders" do
    expect(instance.render?).to be_truthy
    expect(component).to have_css "div"
    expect(instance.send(:organization_registered?)).to be_falsey
    expect(instance.send(:organization_authorized?)).to be_truthy
  end

  context "not organization bike" do
    let(:bike) { FactoryBot.create(:bike) }
    it "renders" do
      expect(instance.render?).to be_truthy
      expect(component).to have_css "div"
    end
  end

  context "without organization" do
    let(:organization) { nil }

    it "doesn't render" do
      expect(instance.render?).to be_falsey
      expect(component).to_not have_css "div"
    end
  end
end
