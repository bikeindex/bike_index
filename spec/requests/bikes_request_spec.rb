require "rails_helper"

RSpec.describe BikesController, type: :request do
  let(:base_url) { "/bikes" }

  describe "show" do
    let(:ownership) { FactoryBot.create(:ownership) }
    let(:current_user) { ownership.creator }
    let(:bike) { ownership.bike }
    before { log_in(current_user) }
    context "example bike" do
      it "shows the bike" do
        ownership.bike.update_attributes(example: true)
        get "#{base_url}/#{bike.id}"
        expect(response).to render_template(:show)
        expect(assigns(:bike).id).to eq bike.id
      end
    end
    context "admin hidden (fake delete)" do
      before { ownership.bike.update_attributes(hidden: true) }
      it "404s" do
        expect do
          get "#{base_url}/#{bike.id}"
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context "user hidden bike" do
      before { bike.update_attributes(marked_user_hidden: "true") }
      context "owner of bike viewing" do
        it "responds with success" do
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(assigns(:bike).id).to eq bike.id
          expect(flash).to_not be_present
        end
      end
      context "Admin viewing" do
        let(:current_user) { FactoryBot.create(:admin) }
        it "responds with success" do
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(assigns(:bike).id).to eq bike.id
          expect(flash).to_not be_present
        end
      end
      context "non-owner non-admin viewing" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "404s" do
          expect do
            get "#{base_url}/#{bike.id}"
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
      context "organization viewing" do
        let(:can_edit_claimed) { false }
        let(:ownership) do
          FactoryBot.create(:ownership_organization_bike,
                            :claimed,
                            organization: organization,
                            can_edit_claimed: can_edit_claimed
                            user: FactoryBot.create(:ownership_claimed))
        end
        let(:bike) { ownership.bike }
        let(:organization) { FactoryBot.create(:organization) }
        let(:current_user) { FactoryBot.create(:organization_member, organization: organization) }
        it "404s" do
          expect(bike.user).to_not eq current_user
          expect(bike.organizations.pluck(:id)).to eq([organization.id])
          expect(bike.visible_by?(current_user)).to be_falsey
          expect do
            get "#{base_url}/#{bike.id}"
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
        context "bike organization editable" do
          let(:can_edit_claimed) { true }
          it "renders" do
            expect(bike.user).to_not eq current_user
            expect(bike.organizations.pluck(:id)).to eq([organization.id])
            expect(bike.visible_by?(current_user)).to be_truthy
            get "#{base_url}/#{bike.id}"
            expect(response.status).to eq(200)
            expect(response).to render_template(:show)
            expect(assigns(:bike).id).to eq bike.id
            expect(flash).to_not be_present
          end
        end
      end
    end
    context "unregistered_parking_notification (also user hidden)" do
      let(:current_organization) { FactoryBot.create(:organization) }
      let(:auto_user) { FactoryBot.create(:organization_member, organization: current_organization) }
      let(:parking_notification) do
        current_organization.update_attributes(auto_user: auto_user)
        FactoryBot.create(:unregistered_parking_notification, organization: current_organization, user: current_organization.auto_user)
      end
      let!(:bike) { parking_notification.bike }

      it "404s" do
        expect do
          get "#{base_url}/#{bike.id}"
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
      context "with org member" do
        include_context :request_spec_logged_in_as_organization_member
        it "renders, even though user hidden" do
          expect(bike.user_hidden).to be_truthy
          expect(bike.owner).to_not eq current_user
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(assigns(:bike)).to eq bike
        end
      end
    end
  end
end
