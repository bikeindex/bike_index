require "rails_helper"

RSpec.describe Organized::StickersController, type: :controller do
  let(:root_path) { organization_bikes_path(organization_id: organization.to_param) }
  let(:stickers_root_path) { organization_stickers_path(organization_id: organization.to_param) }
  let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "partee") }

  before { set_current_user(user) if user.present? }

  context "organization without bike_stickers" do
    let!(:organization) { FactoryBot.create(:organization) }
    context "logged in as organization admin" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      describe "index" do
        it "redirects" do
          get :index, params: {organization_id: organization.to_param}
          expect(response).to redirect_to root_path
        end
      end
      describe "edit" do
        it "redirects" do
          get :edit, params: {id: bike_sticker.code, organization_id: organization.to_param}
          expect(flash[:error]).to be_present
          expect(response).to redirect_to root_path
        end
      end
    end

    context "logged in as super admin" do
      let(:user) { FactoryBot.create(:admin) }
      describe "index" do
        it "renders" do
          get :index, params: {organization_id: organization.to_param}
          expect(response).to render_template(:index)
          expect(assigns(:current_organization)).to eq organization
        end
      end
    end
  end

  context "organization with bike_stickers" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    before { organization.update_column :enabled_feature_slugs, ["bike_stickers"] }

    context "logged in as organization member" do
      describe "index" do
        it "renders" do
          get :index, params: {organization_id: organization.to_param}
          expect(response).to render_template(:index)
          expect(assigns(:current_organization)).to eq organization
          expect(assigns(:bike_stickers).pluck(:id)).to eq([bike_sticker.id])
        end
        context "with query search" do
          let!(:bike_sticker_claimed) { FactoryBot.create(:bike_sticker, organization: organization, code: "part") }
          let!(:bike_sticker_no_org) { FactoryBot.create(:bike_sticker, code: "part") }
          before { bike_sticker_claimed.claim(user: user, bike: FactoryBot.create(:bike).id) }
          it "renders" do
            get :index, params: {organization_id: organization.to_param, search_claimedness: "unclaimed", query: "part"}
            expect(response).to render_template(:index)
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:bike_stickers).pluck(:id)).to eq([bike_sticker.id])
          end
        end
        context "with bike_query" do
          let!(:bike) { FactoryBot.create(:bike) }
          let!(:bike_sticker_claimed) { FactoryBot.create(:bike_sticker, organization: organization, code: "part") }
          before { bike_sticker_claimed.claim(user: user, bike: bike.id) }
          it "renders" do
            expect(BikeSticker.where(bike_id: bike.id).pluck(:id)).to eq([bike_sticker_claimed.id])
            get :index, params: {organization_id: organization.to_param, search_bike: "https://bikeindex.org/bikes/#{bike.id}/edit?cool=stuff"}
            expect(response).to render_template(:index)
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:bike_stickers).pluck(:id)).to eq([bike_sticker_claimed.id])
          end
        end
      end

      describe "edit" do
        it "renders" do
          get :edit, params: {id: bike_sticker.code, organization_id: organization.to_param}
          expect(response).to render_template(:edit)
          expect(assigns(:current_organization)).to eq organization
        end
      end

      describe "update" do
        let(:bike) { FactoryBot.create(:bike) }
        let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike_id: bike.id, organization_id: organization.id) }
        let(:bike2) { FactoryBot.create(:bike) }
        it "updates" do
          bike2.reload
          expect(bike2.organizations.pluck(:id)).to eq([])
          expect {
            put :update, params: {id: bike_sticker.code, organization_id: organization.id, bike_sticker: {bike_id: "https://bikeindex.org/bikes/#{bike2.id} "}}
          }.to change(BikeStickerUpdate, :count).by 1
          expect(assigns(:current_organization)).to eq organization
          expect(flash[:success]).to be_present
          expect(response).to redirect_to bike_path(bike2)
          bike_sticker.reload
          expect(bike_sticker.bike_id).to eq bike2.id
          bike2.reload
          expect(bike2.organizations.pluck(:id)).to eq([organization.id])
        end
        context "passed code rather than id" do
          it "updates" do
            request.env["HTTP_REFERER"] = bike_path(bike2)
            expect {
              put :update, params: {id: "code", organization_id: organization.id, bike_sticker: {bike_id: bike2.id, code: bike_sticker.code}}
            }.to change(BikeStickerUpdate, :count).by 1
            expect(assigns(:current_organization)).to eq organization
            expect(flash[:success]).to be_present
            expect(response).to redirect_to bike_path(bike2)
            bike_sticker.reload
            expect(bike_sticker.bike_id).to eq bike2.id
          end
          context "code blank" do
            it "redirects back" do
              request.env["HTTP_REFERER"] = bike_path(bike2)
              expect {
                put :update, params: {id: "code", organization_id: organization.id, bike_sticker: {bike_id: bike2.id, code: ""}}
              }.to_not change(BikeStickerUpdate, :count)
              expect(assigns(:current_organization)).to eq organization
              expect(flash[:error]).to be_present
              bike_sticker.reload
              expect(bike_sticker.bike_id).to eq bike.id
            end
          end
          context "incomplete code" do
            let(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_id: bike.id, organization_id: organization.id, code: "AA0000151515") }
            it "updates" do
              request.env["HTTP_REFERER"] = bike_path(bike2)
              expect {
                put :update, params: {id: "code", organization_id: organization.id, bike_sticker: {bike_id: bike2.id, code: "151515"}}
              }.to change(BikeStickerUpdate, :count).by 1
              expect(assigns(:current_organization)).to eq organization
              expect(flash[:success]).to be_present
              expect(response).to redirect_to bike_path(bike2)
              bike_sticker.reload
              expect(bike_sticker.bike_id).to eq bike2.id
            end
          end
        end
        context "other organization bike_sticker" do
          let(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_id: bike.id) }
          it "responds with flash error" do
            expect {
              put :update, params: {id: bike_sticker.code, bike_id: bike2.id, organization_id: organization.id}
            }.to change(BikeStickerUpdate, :count).by 1
            expect(flash[:error]).to be_present
            expect(response).to redirect_to edit_organization_sticker_path(organization_id: organization.to_param, id: bike_sticker.code)
            bike_sticker.reload
            expect(bike_sticker.bike.id).to eq bike.id
            expect(bike_sticker.bike_sticker_updates.last.kind).to eq "failed_claim"
          end
        end
        context "nil bike_id" do
          it "updates and removes the assignment" do
            expect {
              put :update, params: {id: bike_sticker.code, bike_id: nil, organization_id: organization.id}
            }.to change(BikeStickerUpdate, :count).by 1
            expect(flash[:success]).to be_present
            expect(response).to redirect_to edit_organization_sticker_path(organization_id: organization.to_param, id: bike_sticker.code)
            bike_sticker.reload
            expect(bike_sticker.claimed_at).to be_nil
            expect(bike_sticker.bike_id).to be_nil
            expect(bike_sticker.user_id).to be_nil
            expect(bike_sticker.previous_bike_id).to eq bike.id
          end
        end
      end
    end
  end
end
