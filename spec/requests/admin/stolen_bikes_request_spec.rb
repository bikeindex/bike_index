require "rails_helper"

base_url = "/admin/stolen_bikes"
RSpec.describe Admin::StolenBikesController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
    let!(:stolen_record) { bike.current_stolen_record }

    describe "index" do
      it "renders" do
        _bike = FactoryBot.create(:bike)
        get base_url
        expect(response.code).to eq("200")
        expect(response).to render_template("index")
        expect(flash).to_not be_present
        expect(assigns(:stolen_records)).to match_array([stolen_record])
      end
    end

    describe "edit" do
      it "responds with 200 OK and renders the edit template" do
        expect(stolen_record.recovery_link_token).to_not be_present
        get "#{base_url}/#{bike.id}/edit"
        stolen_record.reload
        expect(assigns(:current_stolen_record)).to be_truthy
        expect(assigns(:stolen_record)).to eq stolen_record
        expect(stolen_record.recovery_link_token).to be_present
        expect(response.code).to eq("200")
        expect(response).to render_template("edit")
      end
      context "passed the stolen_record_id" do
        let!(:recovered_record) { FactoryBot.create(:stolen_record_recovered, bike: bike) }
        it "renders" do
          bike.reload
          expect(stolen_record.recovery_link_token).to_not be_present
          expect(bike.current_stolen_record).to eq stolen_record
          get "#{base_url}/#{recovered_record.id}/edit?stolen_record_id=1"
          expect(assigns(:stolen_record)).to eq recovered_record
          expect(assigns(:current_stolen_record)).to be_falsey
          expect(response.code).to eq("200")
          expect(response).to render_template("edit")
          expect(flash).to_not be_present
        end
      end
    end

    describe "approve" do
      it "updates the bike and stolen_record and enqueues the job" do
        bike.reload
        stolen_record.reload
        expect(stolen_record.approved).to be_falsey
        Sidekiq::Worker.clear_all
        post "#{base_url}/#{bike.id}/approve"
        bike.reload
        stolen_record.reload
        expect(stolen_record.approved).to be_truthy
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(ApproveStolenListingWorker.jobs.count).to eq 1
        expect(ApproveStolenListingWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([bike.id])
      end
      context "with a theft_alert" do
        let!(:alert_image) { FactoryBot.create(:alert_image, :with_image, stolen_record: stolen_record) }
        let(:theft_alert) { FactoryBot.create(:theft_alert_paid, stolen_record: stolen_record, user: bike.user) }
        it "updates the bike and stolen_record and enqueues the jobs" do
          expect(theft_alert.reload.bike_id).to eq bike.id
          expect(theft_alert.activateable?).to be_falsey
          expect(theft_alert.activateable_except_approval?).to be_truthy
          expect(theft_alert.start_at).to be_blank
          bike.reload
          stolen_record.reload
          expect(stolen_record.approved).to be_falsey
          Sidekiq::Worker.clear_all
          post "#{base_url}/#{bike.id}/approve"
          bike.reload
          stolen_record.reload
          expect(stolen_record.approved).to be_truthy
          expect(flash[:success]).to be_present
          expect(response).to redirect_to(:edit_admin_stolen_bike)
          expect(ApproveStolenListingWorker.jobs.count).to eq 1
          expect(ApproveStolenListingWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([bike.id])

          expect(AfterUserChangeWorker.jobs.count).to eq 1
          AfterUserChangeWorker.drain

          expect(ActivateTheftAlertWorker.jobs.count).to eq 1
          expect(ActivateTheftAlertWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([theft_alert.id])
        end
      end
      context "multi_approve" do
        let(:stolen_record2) { FactoryBot.create(:stolen_record) }
        let!(:stolen_record3) { FactoryBot.create(:stolen_record) }
        it "approves them all" do
          bike.reload
          stolen_record.reload
          expect(stolen_record.approved).to be_falsey
          expect(stolen_record2.approved).to be_falsey
          Sidekiq::Worker.clear_all
          post "#{base_url}/multi_approve/approve", params: {
            sr_selected: {stolen_record.id => stolen_record.id, stolen_record2.id => stolen_record2.id}
          }
          bike.reload
          stolen_record.reload
          expect(stolen_record.approved).to be_truthy
          expect(stolen_record2.reload.approved).to be_truthy
          # Sanity check!
          expect(stolen_record3.reload.approved).to be_falsey
          expect(flash[:success]).to be_present
          expect(ApproveStolenListingWorker.jobs.count).to eq 2
          expect(ApproveStolenListingWorker.jobs.map { |j| j["args"] }.flatten).to eq([bike.id, stolen_record2.bike_id])
        end
      end
    end

    describe "update" do
      it "updates the bike and calls update_ownership and serial_normalizer" do
        expect_any_instance_of(BikeUpdator).to receive(:update_ownership)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        put "#{base_url}/#{bike.id}", params: {bike: {serial_number: "stuff"}}
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(flash[:success]).to be_present
      end
      context "without public image" do
        # Sometimes bikes have alert images even though they have no photo, this enables deleting it
        it "calls regenerates_alert_image" do
          # Stub this call, it proves that the image will be deleted
          expect_any_instance_of(StolenRecord).to receive(:generate_alert_image) { true }
          put "#{base_url}/#{bike.id}", params: {public_image_id: nil, update_action: "regenerate_alert_image"}
          expect(response).to redirect_to(:edit_admin_stolen_bike)
          expect(flash[:success]).to be_present
        end
      end
      context "with public image" do
        let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
        describe "regenerate_alert_image" do
          it "regenerates_alert_image" do
            expect(stolen_record.alert_image).to be_blank
            put "#{base_url}/#{bike.id}", params: {public_image_id: public_image.id, update_action: "regenerate_alert_image"}
            expect(response).to redirect_to(:edit_admin_stolen_bike)
            expect(flash[:success]).to be_present
            stolen_record.reload
            expect(stolen_record.alert_image).to be_present
          end
        end
        describe "delete image" do
          it "deletes image" do
            bike.current_stolen_record.generate_alert_image(bike_image: public_image)
            bike.reload
            expect(bike.current_stolen_record.alert_image).to be_present
            expect(bike.public_images.count).to eq 1
            put "#{base_url}/#{bike.id}", params: {public_image_id: public_image.id, update_action: "delete"}
            expect(response).to redirect_to(:edit_admin_stolen_bike)
            expect(flash[:success]).to be_present
            bike.reload
            expect(bike.public_images.count).to eq 0
            expect(bike.current_stolen_record.alert_image).to be_blank
          end
        end
      end
    end
  end
end
