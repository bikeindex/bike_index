# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationCell::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:options) { {organization:, organization_id:, render_search:} }
  let(:organization) { nil }
  let(:organization_id) { nil }
  let(:render_search) { false }

  context "without organization" do
    it "renders nothing" do
      expect(instance.organization_present?).to be false
    end
  end

  context "with organization" do
    let(:organization) { FactoryBot.create(:organization) }

    it "shows organization is present" do
      expect(instance.organization_present?).to be true
      expect(instance.organization_subject).to eq(organization)
    end
  end

  context "with organization_id" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization_id) { organization.id }

    it "looks up organization by id" do
      expect(instance.organization_present?).to be true
      expect(instance.organization_subject.id).to eq(organization.id)
    end
  end

  context "with missing organization_id" do
    let(:organization_id) { 99999999 }

    it "returns nil for organization_subject" do
      expect(instance.organization_present?).to be true
      expect(instance.organization_subject).to be_nil
    end
  end
end
