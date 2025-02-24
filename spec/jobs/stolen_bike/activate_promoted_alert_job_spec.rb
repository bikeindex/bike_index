require "rails_helper"

facebook_imported = begin
  "Facebook::AdsIntegration".constantize
rescue
  nil
end

if !ENV["CI"] && facebook_imported && Facebook::AdsIntegration::TOKEN.present?
  RSpec.describe StolenBike::ActivatePromotedAlertJob, type: :job do
    let(:instance) { described_class.new }

    describe "perform" do
      let(:promoted_alert_plan) { FactoryBot.create(:promoted_alert_plan, amount_cents_facebook: 3999) }
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
      let(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, bike: bike, approved: true) }
      let(:promoted_alert) { FactoryBot.create(:promoted_alert, :paid, promoted_alert_plan: promoted_alert_plan, stolen_record: stolen_record) }
      before do
        allow_any_instance_of(PromotedAlert).to receive(:facebook_name) { "Test Theft Alert (worker)" }
      end

      # NOTE: This can only be run once - after that, the campaign ID doesn't match, so getting the ads fails
      # it "activates the promoted_alert" do
      #   stolen_record.reload
      #   expect(stolen_record).to be_valid
      #   promoted_alert.reload
      #   expect(promoted_alert.stolen_record_id).to eq stolen_record.id
      #   expect(promoted_alert.paid?).to be_truthy
      #   expect(promoted_alert.missing_location?).to be_falsey
      #   expect(promoted_alert.latitude).to be_present
      #   expect(promoted_alert.longitude).to be_present
      #   expect(promoted_alert.missing_photo?).to be_falsey
      #   expect(promoted_alert.activateable?).to be_truthy
      #   expect(promoted_alert.status).to eq "pending"
      #   expect(promoted_alert.start_at).to be_blank
      #   expect(promoted_alert.facebook_data).to be_blank
      #   Sidekiq::Job.clear_all
      #   VCR.use_cassette("facebook/activate_promoted_alert_worker-success", match_requests_on: [:method]) do
      #     instance.perform(promoted_alert.id)
      #     promoted_alert.reload
      #     expect(promoted_alert.activateable?).to be_truthy
      #     expect(promoted_alert.status).to eq "active"
      #     expect(promoted_alert.start_at).to be_present
      #     expect(promoted_alert.facebook_data.activating_at).to be_present
      #     # Somehow this doesn't show up, in requests after the first request
      #     # expect(promoted_alert.facebook_post_url).to be_present
      #   end
      #   expect(StolenBike::UpdatePromotedAlertFacebookJob.jobs.count).to eq 1
      # end

      describe "failed to activate" do
        let(:timestamp) { (Time.current - 10.minutes).to_i }

        it "doesn't update the activating_at time" do
          stolen_record.reload
          promoted_alert.reload.update(facebook_data: {activating_at: timestamp})
          expect(promoted_alert.reload.failed_to_activate?).to be_truthy
          expect(promoted_alert.activateable_except_approval?).to be_truthy
          expect(promoted_alert.activateable?).to be_truthy

          allow_any_instance_of(Facebook::AdsIntegration).to receive(:create_for).and_raise(StandardError)

          expect {
            instance.perform(promoted_alert.id)
          }.to raise_error(StandardError)

          expect(promoted_alert.reload.failed_to_activate?).to be_truthy
          expect(promoted_alert.facebook_data["activating_at"]).to be_within(1).of timestamp
        end
      end
    end
  end
end
