# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::PotentialDuplicates::Component, type: :component do
  let(:enabled_feature_slugs) { %w[additional_registrations_information] }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }
  let(:bike) { FactoryBot.create(:bike, serial_number: "duplicateserialnumber", cycle_type: "stroller") }
  let(:instance) { described_class.new(bike: bike.reload, organization:, current_user:) }

  it "doesn't render without a duplicate" do
    expect(render_inline(instance).to_html).to be_blank
  end

  context "with a duplicate" do
    let!(:duplicate_bike_group) { FactoryBot.create(:duplicate_bike_group, bike1: bike) }
    let(:duplicate_bike) { duplicate_bike_group.reload.bikes.where.not(id: bike.id).first }

    it "lists the duplicate with the matching segments" do
      render_inline(instance)

      expect(page).to have_text("Potential duplicates")
      expect(page).to have_text("1 found")
      expect(page).to have_text(/Registrations with a serial matching this stroller's segments:\s+DUP11CATE5ER1A1NUM8ER/)
      expect(page).to have_link(href: "/bikes/#{duplicate_bike.id}")
      expect(page).to have_text("DUPLICATESERIALNUMBER")
      expect(page).to_not have_link(href: "/bikes/#{bike.id}")
    end

    it "changes its cache version when another duplicate is registered" do
      expect {
        FactoryBot.create(:duplicate_bike_group, bike1: bike)
      }.to change { described_class.new(bike: bike.reload, organization:, current_user:).cache_version }
    end

    context "without additional_registrations_information" do
      let(:enabled_feature_slugs) { %w[registration_notes] }

      it "doesn't render" do
        expect(render_inline(instance).to_html).to be_blank
        expect(instance.cache_version).to eq([])
      end
    end
  end
end
