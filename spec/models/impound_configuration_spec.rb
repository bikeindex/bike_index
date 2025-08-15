require "rails_helper"

RSpec.describe ImpoundConfiguration, type: :model do
  let(:organization) { impound_configuration.organization }
  let(:user) { organization.auto_user }

  describe "factory is valid" do
    let(:impound_configuration) { FactoryBot.create(:impound_configuration, public_view: true, display_id_prefix: " ") }
    it "is valid, organization is enabled" do
      expect(impound_configuration).to be_valid
      expect(impound_configuration.public_view?).to be_truthy
      organization = impound_configuration.organization
      expect(organization.reload.impound_claims?).to be_truthy
      expect(organization.enabled_feature_slugs).to include("impound_bikes_public")

      expect(impound_configuration.display_id_prefix).to eq nil
      expect(organization.reload.enabled?("impound_bikes")).to be_truthy
      expect(organization.public_impound_bikes?).to be_truthy
    end
  end

  describe "calculated_display_id_next_integer" do
    let(:impound_configuration) { FactoryBot.create(:impound_configuration) }
    it "returns 1" do
      expect(impound_configuration.calculated_display_id_next_integer).to eq 1
      expect(impound_configuration.calculated_display_id_next).to eq "1"
      impound_record1 = organization.impound_records.create(display_id_integer: 12, bike: FactoryBot.create(:bike))
      expect(impound_record1).to be_valid
      expect(impound_record1.display_id).to eq "12"
      expect(impound_configuration.calculated_display_id_next_integer).to eq 13
      expect(impound_configuration.calculated_display_id_next).to eq "13"
      expect(impound_configuration.previous_prefixes).to eq([])
    end
    context "with display_id_prefix" do
      let(:impound_configuration) { FactoryBot.create(:impound_configuration, display_id_prefix: "c8s") }
      it "returns with prefix" do
        expect(impound_configuration.calculated_display_id_next_integer).to eq 1
        expect(impound_configuration.calculated_display_id_next).to eq "c8s1"
        impound_record1 = organization.impound_records.create(display_id_integer: 12, bike: FactoryBot.create(:bike))
        expect(impound_record1).to be_valid
        expect(impound_record1.display_id).to eq "c8s12"
        expect(impound_configuration.calculated_display_id_next_integer).to eq 13
        expect(impound_configuration.calculated_display_id_next).to eq "c8s13"
        impound_record2 = organization.impound_records.create(display_id_integer: 100, display_id_prefix: "c8s", bike: FactoryBot.create(:bike))
        expect(impound_record2).to be_valid
        expect(impound_record2.display_id).to eq "c8s100"
        expect(impound_configuration.calculated_display_id_next_integer).to eq 101
        expect(impound_configuration.calculated_display_id_next).to eq "c8s101"
        expect(impound_configuration.previous_prefixes).to eq(["c8s"])
      end
    end
    context "with display_id_next_integer" do
      let(:impound_configuration) { FactoryBot.create(:impound_configuration, display_id_prefix: "A", display_id_next_integer: 1212) }
      it "returns with the next" do
        expect(impound_configuration.calculated_display_id_next_integer).to eq 1212
        expect(impound_configuration.calculated_display_id_next).to eq "A1212"
        # The process worker is the thing that removes the display_id_next - so we have to run it
        Sidekiq::Job.clear_all
        expect {
          organization.impound_records.create(bike: FactoryBot.create(:bike))
        }.to change(ProcessImpoundUpdatesJob.jobs, :count).by 1
        ProcessImpoundUpdatesJob.drain
        expect(impound_configuration.reload.calculated_display_id_next_integer).to eq 1213
        expect(impound_configuration.calculated_display_id_next).to eq "A1213"
        expect(impound_configuration.display_id_next_integer).to eq nil
        expect(impound_configuration.previous_prefixes).to eq(["A"])
      end
    end
  end
end
