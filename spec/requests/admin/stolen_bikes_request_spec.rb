require "rails_helper"

base_url = "/admin/stolen_bikes"
RSpec.describe Admin::StolenBikesController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let!(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike) }
    let(:stolen_record) { bike.current_stolen_record }

    describe "index" do
      it "renders" do
        _bike = FactoryBot.create(:bike)
        get base_url
        expect(response.code).to eq("200")
        expect(response).to render_template("index")
        expect(flash).to_not be_present
        expect(assigns(:bikes)).to match_array([bike])
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
        expect(bike.approved_stolen).to be_falsey
        expect(stolen_record.approved).to be_falsey
        Sidekiq::Worker.clear_all
        post "#{base_url}/#{bike.id}/approve"
        bike.reload
        stolen_record.reload
        expect(bike.approved_stolen).to be_truthy
        expect(stolen_record.approved).to be_truthy
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(ApproveStolenListingWorker.jobs.count).to eq 1
        expect(ApproveStolenListingWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([bike.id])
      end
    end

    describe "update" do
      it "updates the bike and calls update_ownership and serial_normalizer" do
        expect_any_instance_of(BikeUpdator).to receive(:update_ownership)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        ownership = FactoryBot.create(:ownership)
        bike = ownership.bike
        put "#{base_url}/#{bike.id}", params: { bike: { serial_number: "stuff" } }
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(flash[:success]).to be_present
      end
      context "with public image" do
        let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
        describe "regenerate_alert_image" do
          it "regenerates_alert_image" do
            expect(stolen_record.alert_image).to be_blank
            put "#{base_url}/#{bike.id}", params: { public_image_id: public_image.id, update_action: "regenerate_alert_image"  }
            expect(response).to redirect_to(:edit_admin_stolen_bike)
            expect(flash[:success]).to be_present
            stolen_record.reload
            expect(stolen_record.alert_image).to be_present
          end
        end
        describe "delete image" do
          it "deletes image" do
            expect(bike.public_images.count).to eq 1
            put "#{base_url}/#{bike.id}", params: { public_image_id: public_image.id, update_action: "delete"  }
            expect(response).to redirect_to(:edit_admin_stolen_bike)
            expect(flash[:success]).to be_present
            bike.reload
            expect(bike.public_images.count).to eq 0
          end
        end
      end
    end
  end
end
