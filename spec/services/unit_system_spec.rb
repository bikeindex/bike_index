require "rails_helper"

RSpec.describe UnitSystem do
  describe "metric?" do
    it "is metric outside the US, and without a country" do
      expect(described_class.metric?).to be_truthy
      expect(described_class.metric?(country_id: Country.canada_id)).to be_truthy
      expect(described_class.metric?(country_id: Country.united_states_id)).to be_falsey
    end

    context "with a user" do
      let(:user) { FactoryBot.create(:user) }

      it "uses the request's country" do
        expect(described_class.metric?(user:, country_id: Country.united_states_id)).to be_falsey
        expect(described_class.metric?(user:, country_id: Country.canada_id)).to be_truthy
      end

      context "with a US address" do
        let(:user) { FactoryBot.create(:user, :with_address_record, address_in: :new_york) }

        it "uses the address over the request" do
          expect(described_class.metric?(user:, country_id: Country.canada_id)).to be_falsey
        end

        context "with a preference" do
          before { user.update(preferred_unit_system: "metric") }

          it "uses the preference" do
            expect(described_class.metric?(user:, country_id: Country.united_states_id)).to be_truthy
            user.update(preferred_unit_system: "imperial")
            expect(described_class.metric?(user:, country_id: Country.canada_id)).to be_falsey
          end
        end
      end
    end
  end

  describe "permitted_distance_unit" do
    it "is miles unless it's kilometers" do
      expect(described_class.permitted_distance_unit("km")).to eq "km"
      expect(described_class.permitted_distance_unit("mi")).to eq "mi"
      expect(described_class.permitted_distance_unit("furlongs")).to eq "mi"
      expect(described_class.permitted_distance_unit(nil)).to eq "mi"
    end
  end

  describe "to_miles and from_miles" do
    it "converts kilometers, and leaves miles alone" do
      expect(described_class.to_miles(100, "km")).to be_within(0.01).of 62.14
      expect(described_class.to_miles(100, "mi")).to eq 100
      expect(described_class.from_miles(100, "km")).to be_within(0.01).of 160.93
      expect(described_class.from_miles(100, "mi")).to eq 100
    end
  end
end
