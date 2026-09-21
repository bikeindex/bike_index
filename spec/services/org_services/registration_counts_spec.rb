# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrgServices::RegistrationCounts do
  let(:organization) { FactoryBot.create(:organization) }
  let(:bikes) { organization.bikes }
  let(:time_range) { (Time.current - 1.week)..Time.current }

  describe "for_range" do
    let(:stats) { described_class.for_range(bikes, time_range) }

    it "returns a zeroed row per metric" do
      expect(stats.map(&:key)).to eq %i[registrations motorized stolen]
      expect(stats.map(&:count)).to eq [0, 0, 0]
      expect(stats.map(&:delta_display)).to eq [nil, nil, nil]
    end

    context "with bikes in the window and the one before it" do
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, created_at: Time.current - 1.day) }
      let!(:motorized) do
        FactoryBot.create(:bike_organized, creation_organization: organization,
          propulsion_type: "throttle", created_at: Time.current - 2.days)
      end
      let!(:earlier) do
        FactoryBot.create(:bike_organized, creation_organization: organization,
          created_at: Time.current - 10.days)
      end

      it "counts the window and compares it against the one before" do
        expect(stats.map(&:count)).to eq [2, 1, 0]
        expect(stats.first.previous_count).to eq 1
        expect(stats.first.delta_display).to eq "+100%"
      end

      context "with compare false" do
        let(:stats) { described_class.for_range(bikes, time_range, compare: false) }

        it "leaves every row without a comparison" do
          expect(stats.map(&:previous_count)).to eq [nil, nil, nil]
          expect(stats.map(&:delta_display)).to eq [nil, nil, nil]
        end
      end
    end

    context "with a stolen bike" do
      let!(:bike) do
        FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization,
          created_at: Time.current - 1.day)
      end

      it "counts it under stolen as well as registrations" do
        expect(stats.map(&:count)).to eq [1, 0, 1]
      end
    end
  end
end
