require "rails_helper"

facebook_imported = begin
  "Facebook::AdsIntegration".constantize
rescue
  nil
end

if !ENV["CI"] && facebook_imported && Facebook::AdsIntegration::TOKEN.present?
  RSpec.describe StolenBike::ActivateTheftAlertJob, type: :job do
    let(:instance) { described_class.new }

    describe "perform" do
      let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, amount_cents_facebook: 3999) }
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
      let(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, bike: bike, approved: true) }
      let(:theft_alert) { FactoryBot.create(:theft_alert, :paid, theft_alert_plan: theft_alert_plan, stolen_record: stolen_record) }
      before do
        allow_any_instance_of(TheftAlert).to receive(:facebook_name) { "Test Theft Alert (worker)" }
      end

      # NOTE: This can only be run once - after that, the campaign ID doesn't match, so getting the ads fails
      # it "activates the theft_alert" do
      #   stolen_record.reload
      #   expect(stolen_record).to be_valid
      #   theft_alert.reload
      #   expect(theft_alert.stolen_record_id).to eq stolen_record.id
      #   expect(theft_alert.paid?).to be_truthy
      #   expect(theft_alert.missing_location?).to be_falsey
      #   expect(theft_alert.latitude).to be_present
      #   expect(theft_alert.longitude).to be_present
      #   expect(theft_alert.missing_photo?).to be_falsey
      #   expect(theft_alert.activateable?).to be_truthy
      #   expect(theft_alert.status).to eq "pending"
      #   expect(theft_alert.start_at).to be_blank
      #   expect(theft_alert.facebook_data).to be_blank
      #   Sidekiq::Job.clear_all
      #   VCR.use_cassette("facebook/activate_theft_alert_worker-success", match_requests_on: [:method]) do
      #     instance.perform(theft_alert.id)
      #     theft_alert.reload
      #     expect(theft_alert.activateable?).to be_truthy
      #     expect(theft_alert.status).to eq "active"
      #     expect(theft_alert.start_at).to be_present
      #     expect(theft_alert.facebook_data.activating_at).to be_present
      #     # Somehow this doesn't show up, in requests after the first request
      #     # expect(theft_alert.facebook_post_url).to be_present
      #   end
      #   expect(StolenBike::UpdateTheftAlertFacebookJob.jobs.count).to eq 1
      # end

      describe "failed to activate" do
        let(:timestamp) { (Time.current - 10.minutes).to_i }

        it "doesn't update the activating_at time" do
          stolen_record.reload
          theft_alert.reload.update(facebook_data: {activating_at: timestamp})
          expect(theft_alert.reload.failed_to_activate?).to be_truthy
          expect(theft_alert.activateable_except_approval?).to be_truthy
          expect(theft_alert.activateable?).to be_truthy

          allow_any_instance_of(Facebook::AdsIntegration).to receive(:create_for).and_raise(StandardError)

          expect {
            instance.perform(theft_alert.id)
          }.to raise_error(StandardError)

          expect(theft_alert.reload.failed_to_activate?).to be_truthy
          expect(theft_alert.facebook_data["activating_at"]).to be_within(1).of timestamp
        end
      end
    end
  end
end
