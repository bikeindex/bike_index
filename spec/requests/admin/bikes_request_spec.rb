require "rails_helper"

base_url = "/admin/bikes"
RSpec.describe Admin::BikesController, type: :request do
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    describe "destroy" do
      it "destroys the bike" do
        ownership = bike.current_ownership
        expect do
          delete "#{base_url}/#{bike.id}"
        end.to change(Bike, :count).by(-1)
        expect(response).to redirect_to(:admin_bikes)
        expect(flash[:success]).to match(/deleted/i)
        expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id)
      end
    end

    describe "update" do
      it "updates the user email, without sending email" do
        expect(bike.current_ownership).to be_present
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          expect do
            put "#{base_url}/#{bike.id}", params: { bike: { owner_email: "new@example.com", skip_email: "1" } }
          end.to change(Ownership, :count).by 1
        end
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(:edit_admin_bike)
        bike.reload
        expect(bike.current_ownership.owner_email).to eq "new@example.com"
        expect(bike.current_ownership.send_email).to be_falsey
      end
      context "with user deleted" do
        let(:user) { FactoryBot.create(:user) }
        let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
        it "updates" do
          user.destroy
          bike.reload
          expect(bike.current_ownership).to be_present
          Sidekiq::Worker.clear_all
          ActionMailer::Base.deliveries = []
          Sidekiq::Testing.inline! do
            expect do
              put "#{base_url}/#{bike.id}", params: { bike: { owner_email: "new@example.com", skip_email: "false" } }
            end.to change(Ownership, :count).by 1
          end
          expect(ActionMailer::Base.deliveries.count).to eq 1
          expect(flash[:success]).to be_present
          expect(response).to redirect_to(:edit_admin_bike)
          bike.reload
          expect(bike.current_ownership.owner_email).to eq "new@example.com"
          expect(bike.current_ownership.send_email).to be_truthy
        end
      end
    end
  end
end
