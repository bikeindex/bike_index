require "rails_helper"

base_url = "/api/v1/users"
RSpec.describe API::V1::UsersController, type: :request do
  describe "current" do
    it "returns user_present = false if there is no user present" do
      get "#{base_url}/current", headers: {format: :json}
      expect(response.code).to eq("200")
      expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
      expect(response.headers["Access-Control-Request-Method"]).not_to be_present
    end

    it "returns user_present if a user is present" do
      # We need to test that cors isn't present
      u = FactoryBot.create(:user_confirmed)
      log_in(u)
      get "#{base_url}/current", headers: {format: :json}
      expect(response.code).to eq("200")
      expect(json_result).to include("user_present" => true)
      expect(json_result["email"]).to_not be_present
      expect(response.headers["Access-Control-Allow-Origin"]).not_to be_present
      expect(response.headers["Access-Control-Request-Method"]).not_to be_present
    end
  end

  describe "send_request" do
    context "delete request" do
      let(:ownership) { FactoryBot.create(:ownership) }
      let(:user) { ownership.creator }
      let(:bike) { ownership.bike }
      it "actually send the mail" do
        Sidekiq::Testing.inline! do
          # We don't test that this is being added to Sidekiq
          # Because we're testing that sidekiq does what it
          # Needs to do here. Slow tests, but we know it actually works :(
          delete_request = {
            request_type: "bike_delete_request",
            user_id: user.id,
            request_bike_id: bike.id,
            request_reason: "Some reason"
          }
          log_in(user)
          ActionMailer::Base.deliveries = []
          post "#{base_url}/send_request", params: delete_request
          expect(response.code).to eq("200")
          expect(ActionMailer::Base.deliveries).to be_empty
          bike.reload
          expect(bike.paranoia_destroyed?).to be_truthy
        end
      end
      context "bike is authorized by user" do
        let(:organization) { FactoryBot.create(:organization, name: "Pro's Closet", short_name: "tpc") }
        let(:user) { FactoryBot.create(:organization_user, organization: organization) }
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
        let!(:ownership) { FactoryBot.create(:ownership, bike: bike) }
        let(:delete_params) do
          {
            request_type: "bike_delete_request",
            user_id: user.id,
            request_bike_id: bike.id,
            request_reason: "Some reason"
          }
        end
        before { log_in(user) }
        def expect_bike_to_be_destroyed(passed_bike, passed_url, passed_params)
          Sidekiq::Testing.inline! do
            # We don't test that this is being added to Sidekiq
            # Because we're testing that sidekiq does what it
            # Needs to do here. Slow tests, but we know it actually works :(
            ActionMailer::Base.deliveries = []
            post passed_url, params: passed_params
            expect(response.code).to eq("200")
            expect(ActionMailer::Base.deliveries).to be_empty
            passed_bike.reload
            expect(passed_bike.paranoia_destroyed?).to be_truthy
          end
        end
        it "actually sends the email" do
          expect(user).to be_present
          expect_bike_to_be_destroyed(bike, "#{base_url}/send_request", delete_params)
        end
        context "marketplace_listing" do
          let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: bike) }
          it "marks removed" do
            expect_bike_to_be_destroyed(bike, "#{base_url}/send_request", delete_params)
            expect(marketplace_listing.reload.status).to eq "removed"
            expect(marketplace_listing.end_at).to be_within(5).of Time.current
          end
        end
        context "marketplace_listing sold" do
          let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :sold, item: bike) }
          it "doesn't update marketplace_listing" do
            expect_bike_to_be_destroyed(bike, "#{base_url}/send_request", delete_params)
            expect(marketplace_listing.reload.status).to eq "sold"
          end
        end
      end
    end
    context "manufacturer_update_manufacturer present" do
      it "updates the manufacturer" do
        o = FactoryBot.create(:ownership)
        manufacturer = FactoryBot.create(:manufacturer)
        user = o.creator
        bike = o.bike
        update_manufacturer_request = {
          request_type: "manufacturer_update_manufacturer",
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: "Need to update manufacturer",
          manufacturer_update_manufacturer: manufacturer.slug
        }
        log_in(user)
        post "#{base_url}/send_request", params: update_manufacturer_request
        expect(response.code).to eq("200")
        bike.reload
        expect(bike.manufacturer).to eq manufacturer
      end
    end

    context "manufacturer_update_manufacturer present" do
      it "does not make nil manufacturer" do
        o = FactoryBot.create(:ownership)
        user = o.creator
        bike = o.bike
        update_manufacturer_request = {
          request_type: "manufacturer_update_manufacturer",
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: "Need to update manufacturer",
          manufacturer_update_manufacturer: "doadsfizxcv"
        }
        log_in(user)
        post "#{base_url}/send_request", params: update_manufacturer_request
        expect(response.code).to eq("200")
        bike.reload
        expect(bike.manufacturer).to be_present
      end
    end

    context "serial request mail" do
      it "doesn't create a new serial request mail" do
        o = FactoryBot.create(:ownership)
        user = o.creator
        bike = o.bike
        serial_request = {
          request_type: "serial_update_request",
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: "Some reason",
          serial_update_serial: "some new serial"
        }
        log_in(user)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        expect {
          post "#{base_url}/send_request", params: serial_request
        }.to change(Email::FeedbackNotificationJob.jobs, :size).by(0)
        expect(response.code).to eq("200")
        expect(bike.reload.serial_number).to eq("some new serial")
      end
    end

    it "it untsvs a bike" do
      t = Time.current - 1.minute
      stolen_record = FactoryBot.create(:stolen_record, tsved_at: t)
      o = FactoryBot.create(:ownership, bike: stolen_record.bike)
      user = o.creator
      bike = o.bike
      bike.fetch_current_stolen_record.id
      bike.save
      serial_request = {
        request_type: "serial_update_request",
        user_id: user.id,
        request_bike_id: bike.id,
        request_reason: "Some reason",
        serial_update_serial: "some new serial"
      }
      log_in(user)
      expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
      post "#{base_url}/send_request", params: serial_request
      expect(response.code).to eq("200")
      bike.reload
      expect(bike.serial_number).to eq("some new serial")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_nil
    end

    describe "recovery" do
      let(:bike) { FactoryBot.create(:stolen_bike) }
      let(:stolen_record) { bike.current_stolen_record }
      let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
      let(:user) { ownership.creator }
      let(:recovery_request) do
        {
          request_type: "bike_recovery",
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: "Some reason",
          index_helped_recovery: "true",
          can_share_recovery: "true",
          mark_recovered_stolen_record_id: stolen_record.id
        }
      end

      before do
        expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id
        log_in(user)
      end

      it "recovers the bike" do
        bike.reload
        expect(bike.current_stolen_record_id).to eq stolen_record.id
        og_updated_at = bike.updated_at
        post "#{base_url}/send_request", params: recovery_request.as_json
        expect(response.code).to eq("200")
        bike.reload
        stolen_record.reload
        feedback = Feedback.last

        expect(bike.status_stolen?).to be_falsey
        expect(bike.current_stolen_record_id).to be_blank
        expect(bike.updated_at).to be > og_updated_at
        expect(feedback.body).to eq recovery_request[:request_reason]
        expect(feedback.feedback_hash).to eq recovery_request
          .slice(:index_helped_recovery, :can_share_recovery)
          .merge(bike_id: bike.id.to_s).as_json
        expect(bike.status).to eq "status_with_owner"
        expect(stolen_record.current).to be_falsey
        expect(stolen_record.bike).to eq(bike)
        expect(stolen_record.recovered?).to be_truthy
        expect(stolen_record.recovered_description).to eq recovery_request[:request_reason]
        expect(stolen_record.recovered_at).to be_present
        expect(stolen_record.recovery_posted).to be_falsey
        expect(stolen_record.index_helped_recovery).to be_truthy
        expect(stolen_record.can_share_recovery).to be_truthy
      end
      context "with a promoted alert" do
        let!(:theft_alert) { FactoryBot.create(:theft_alert_ended, stolen_record: stolen_record, user: user) }
        it "sends an email to admins" do
          expect(theft_alert.active?).to be_falsey
          bike.reload
          expect(bike.current_stolen_record).to eq stolen_record

          Sidekiq::Job.clear_all
          ActionMailer::Base.deliveries = []
          Sidekiq::Testing.inline! do
            post "#{base_url}/send_request", params: recovery_request.as_json
          end
          expect(response.code).to eq("200")
          bike.reload
          stolen_record.reload

          expect(bike.status_stolen?).to be_falsey
          expect(stolen_record.current).to be_falsey
          expect(stolen_record.bike).to eq(bike)
          expect(stolen_record.recovered?).to be_truthy
          expect(stolen_record.recovered_description).to eq recovery_request[:request_reason]
          expect(stolen_record.recovered_at).to be_present
          expect(stolen_record.recovery_posted).to be_falsey
          expect(stolen_record.index_helped_recovery).to be_truthy
          expect(stolen_record.can_share_recovery).to be_truthy
          expect(ActionMailer::Base.deliveries.count).to eq 2
          mail_subjects = ActionMailer::Base.deliveries.map(&:subject)
          expect(mail_subjects).to match_array(["Bike Recovery", "RECOVERED Promoted Alert: #{theft_alert.id}"])
        end
      end
    end

    it "does not create a new serial request mailer if a user isn't present" do
      bike = FactoryBot.create(:bike)
      message = {request_bike_id: bike.id, serial_update_serial: "some update", request_reason: "Some reason"}
      post "#{base_url}/send_request", params: message.merge(format: :json)
      expect(response.code).to eq("403")
    end

    it "does not create a new serial request mailer if wrong user user is present" do
      o = FactoryBot.create(:ownership)
      bike = o.bike
      user = FactoryBot.create(:user_confirmed)
      log_in(user)
      params = {request_bike_id: bike.id, serial_update_serial: "some update", request_reason: "Some reason"}
      post "#{base_url}/send_request", params: params
      expect(response.code).to eq("403")
    end
  end
end
