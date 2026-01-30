require "rails_helper"

RSpec.shared_examples "search_radius_metricable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) do
    if model_sym == :organization
      organization
    elsif model_sym == :organization_stolen_message # No factory
      OrganizationStolenMessage.create(organization: organization)
    else
      FactoryBot.create(model_sym, organization: organization)
    end
  end
  let(:location) { organization.locations.first }

  describe "search_radius_metric_units?" do
    context "us organization" do
      let(:organization) { FactoryBot.create(:organization, :in_nyc) }
      it "is false, but you can still set kilometers" do
        expect(instance.search_radius_metric_units?).to be_falsey
        instance.update(search_radius_kilometers: 10)
        expect(instance.search_radius_metric_units?).to be_falsey
        expect(instance.reload.search_radius_kilometers).to eq 10
        expect(instance.search_radius_miles.round(1)).to eq 6.2
      end
    end
    context "not US organization" do
      let(:organization) { FactoryBot.create(:organization, :in_edmonton) }
      it "is truthy" do
        expect(location.address_record.country).to eq Country.canada
        expect(location.address_record.region_record).to be_present
        expect(location.latitude).to be_within(0.1).of 53.5069377

        expect(instance.search_radius_metric_units?).to be_truthy
        instance.search_radius_kilometers = 400
        expect(instance.search_radius_kilometers).to eq 400

        # Also, set default to a round number
        instance.search_radius_miles = nil
        instance.validate
        expect(instance.search_radius_kilometers).to eq 100
      end
    end
  end
end
