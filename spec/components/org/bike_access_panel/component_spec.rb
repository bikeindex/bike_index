# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeAccessPanel::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {bike:, organization:, current_user:} }
  let(:bike) { FactoryBot.create(:bike) }
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

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
    let(:can_edit_claimed) { true }
    let(:marked_user_hidden) { false }

    it "renders" do
      expect(instance.render?).to be_truthy
      expect(component).to have_css "div"
      expect(instance.send(:organization_registered?)).to be_truthy
      expect(instance.send(:organization_authorized?)).to be_truthy
      expect(instance.send(:user_can_edit?)).to be_truthy
    end

    context "can_edit_claimed: false" do
      let(:can_edit_claimed) { false }
      it "renders" do
        expect(instance.render?).to be_truthy
        expect(component).to have_css "div"
        expect(instance.send(:organization_registered?)).to be_truthy
        expect(instance.send(:organization_authorized?)).to be_falsey
        expect(instance.send(:user_can_edit?)).to be_falsey
      end
    end

    context "marked_user_hidden: true" do
      let(:marked_user_hidden) { true }

      it "renders" do
        expect(instance.render?).to be_truthy
        expect(component).to have_css "div"
        expect(instance.send(:organization_registered?)).to be_truthy
        expect(instance.send(:organization_authorized?)).to be_truthy
        expect(instance.send(:user_can_edit?)).to be_truthy
      end

      context "can_edit_claimed: false" do
        let(:can_edit_claimed) { false }
        it "doesn't render" do
          # Currently, the page also 404s - but just to keep things safe
          expect(bike.reload.authorized?(current_user)).to be_falsey
          expect(bike.user_hidden).to be_truthy
          expect(bike.visible_by?(current_user)).to be_falsey
          expect(instance.render?).to be_falsey
          expect(component).to_not have_css "div"
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

    context "with model audit and duplicate bike" do
      let(:enabled_feature_slugs) { %w[model_audits additional_registration_information] }
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
      let(:model_audit) { FactoryBot.create(:model_audit, frame_model: "Some crazy model", manufacturer: bike.manufacturer) }
      let!(:organization_model_audit) { FactoryBot.create(:organization_model_audit, organization:, model_audit:) }
      let!(:model_attestation) { FactoryBot.create(:model_attestation, organization:, model_audit:) }
      let!(:duplicate_bike_group) { FactoryBot.create(:duplicate_bike_group, bike1: bike) }
      before { bike.update(model_audit_id: model_audit.id) }

      it "renders the model_audit" do
        expect(duplicate_bike_group.reload.bikes.count).to eq 2
        expect(bike.reload.duplicate_bike_groups.pluck(:id)).to eq([duplicate_bike_group.id])

        expect(instance.render?).to be_truthy
        expect(component).to have_css "div"
        expect(instance.send(:organization_registered?)).to be_truthy
        expect(instance.send(:organization_authorized?)).to be_truthy
        expect(instance.send(:user_can_edit?)).to be_truthy

        component_text = whitespace_normalized_body_text(component.to_html)
        expect(component_text).to match(/#{bike.mnfg_name} Some crazy model/)
        pp component_text
        expect(component_text).to match(/duplicate bikeddd/)
      end
    end

    context "phoneable by" do
    end
  end

  context "not organization bike" do
    let(:bike) { FactoryBot.create(:bike) }
    it "renders" do
      expect(instance.render?).to be_truthy
      expect(component).to have_css "div"
    end
  end

  context "without organization membership" do
    let(:current_user) { FactoryBot.create(:user) }

    it "doesn't render" do
      expect(current_user.reload.authorized?(organization)).to be_falsey
      expect(instance.render?).to be_falsey
      expect(component).to_not have_css "div"
    end
  end
end
