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
    expect(instance.send(:organization_authorized?)).to be_falsey
    expect(instance.send(:user_can_edit?)).to be_falsey
  end

  context "bike_authorized" do
    let(:bike) do
      FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization,
        can_edit_claimed:, marked_user_hidden:)
    end
    let(:can_edit_claimed) { false }
    let(:marked_user_hidden) { false }

    it "renders" do
      expect(instance.render?).to be_truthy
      expect(component).to have_css "div"
      expect(instance.send(:organization_registered?)).to be_truthy
      expect(instance.send(:organization_authorized?)).to be_falsey
      expect(instance.send(:user_can_edit?)).to be_falsey
    end

    context "marked_user_hidden: true" do
      let(:marked_user_hidden) { true }

      it "doesn't render" do
        expect(bike.reload.authorized?(current_user)).to be_falsey
        expect(bike.user_hidden).to be_truthy
        expect(bike.visible_by?(current_user)).to be_falsey
        expect(instance.render?).to be_falsey
        expect(component).to_not have_css "div"
      end

      context "can_edit_claimed: true" do
        let(:can_edit_claimed) { true }
        it "renders" do
          expect(instance.render?).to be_truthy
          expect(component).to have_css "div"
          expect(instance.send(:organization_registered?)).to be_truthy
          expect(instance.send(:organization_authorized?)).to be_truthy
          expect(instance.send(:user_can_edit?)).to be_truthy
        end
      end
    end

    context "bike deleted" do
      before { bike.delete }
      it "doesn't render" do
        expect(instance.render?).to be_falsey
        expect(component).to_not have_css "div"
      end
    end
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
