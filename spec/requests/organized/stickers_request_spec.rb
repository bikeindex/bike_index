require "rails_helper"

RSpec.describe Organized::StickersController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/stickers" }
  let(:root_path) { organization_bikes_path(organization_id: current_organization.to_param) }
  let(:stickers_root_path) { organization_stickers_path(organization_id: current_organization.to_param) }
  let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: current_organization, code: "laxee") }

  context "organization without bike_stickers" do
    context "logged in as organization admin" do
      include_context :request_spec_logged_in_as_organization_admin
      describe "index" do
        it "redirects" do
          get base_url
          expect(response).to redirect_to organization_root_path(organization_id: current_organization.to_param)
        end
      end
      describe "edit" do
        it "redirects" do
          get "#{base_url}/#{bike_sticker.code}/edit"
          expect(flash[:error]).to be_present
          expect(response).to redirect_to organization_root_path(organization_id: current_organization.to_param)
        end
      end
    end

    context "logged in as super admin" do
      let!(:current_organization) { FactoryBot.create(:organization) }
      include_context :request_spec_logged_in_as_superuser
      describe "index" do
        it "renders" do
          get base_url
          expect(response).to render_template(:index)
          expect(assigns(:current_organization)&.id).to eq current_organization.id
        end
      end
    end
  end

  context "organization with bike_stickers" do
    include_context :request_spec_logged_in_as_organization_user
    let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["bike_stickers"]) }

    context "logged in as organization member" do
      describe "index" do
        let!(:bike_sticker2) { FactoryBot.create(:bike_sticker, secondary_organization: current_organization) }
        it "renders" do
          get base_url
          expect(response).to render_template(:index)
          expect(assigns(:current_organization)&.id).to eq current_organization.id
          expect(assigns(:bike_stickers).pluck(:id)).to match_array([bike_sticker.id, bike_sticker2.id])
        end
        context "with query search" do
          let!(:bike_sticker_claimed) { FactoryBot.create(:bike_sticker, organization: current_organization, code: "lax01222") }
          let!(:bike_sticker2) { FactoryBot.create(:bike_sticker, organization: current_organization, code: "lax122") }
          let!(:bike_sticker_no_org) { FactoryBot.create(:bike_sticker, code: "lax01222") }
          before { bike_sticker_claimed.reload.claim(user: current_user, bike: FactoryBot.create(:bike).id) }
          it "renders, finds the stickers we expect" do
            get base_url, params: {search_claimedness: "unclaimed", query: "lax"}
            expect(response).to render_template(:index)
            expect(assigns(:current_organization)&.id).to eq current_organization.id
            expect(assigns(:bike_stickers).pluck(:id)).to match_array([bike_sticker.id, bike_sticker2.id])
            # And check that searches match expected things
            get base_url, params: {query: "lax12"}
            expect(assigns(:bike_stickers).pluck(:id)).to match_array([bike_sticker2.id, bike_sticker_claimed.id])
            get base_url, params: {query: "lax0122"}
            expect(assigns(:bike_stickers).pluck(:id)).to match_array([bike_sticker_claimed.id])
            get base_url, params: {query: "lax1222"}
            expect(assigns(:bike_stickers).pluck(:id)).to eq([bike_sticker_claimed.id])
            # And check that it redirects to the sticker path
            get "/bikes/scanned/#{bike_sticker2.code}"
            expect(response).to redirect_to(organization_bikes_path(bike_sticker: bike_sticker2.code, organization_id: current_organization.to_param))
          end
        end
        context "with bike_query" do
          let!(:bike) { FactoryBot.create(:bike) }
          let!(:bike_sticker_claimed) { FactoryBot.create(:bike_sticker, organization: current_organization, code: "lax") }
          before { bike_sticker_claimed.reload.claim(user: current_user, bike: bike.id) }
          it "renders" do
            expect(BikeSticker.where(bike_id: bike.id).pluck(:id)).to eq([bike_sticker_claimed.id])
            get base_url, params: {organization_id: current_organization.to_param, search_bike: "https://bikeindex.org/bikes/#{bike.id}/edit?cool=stuff"}
            expect(response).to render_template(:index)
            expect(assigns(:current_organization)&.id).to eq current_organization.id
            expect(assigns(:bike_stickers).pluck(:id)).to eq([bike_sticker_claimed.id])
          end
        end
      end

      describe "edit" do
        it "renders" do
          get "#{base_url}/#{bike_sticker.code}/edit"
          expect(response).to render_template(:edit)
          expect(assigns(:current_organization)&.id).to eq current_organization.id
        end
      end

      describe "update" do
        let(:bike) { FactoryBot.create(:bike) }
        let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike, organization_id: current_organization.id) }
        let(:bike2) { FactoryBot.create(:bike) }
        it "updates" do
          bike_sticker.reload
          expect(bike_sticker.bike_sticker_updates.count).to eq 1
          expect(bike_sticker.previous_bike_id).to be_blank
          expect(bike_sticker.bike_id).to eq bike.id
          bike2.reload
          expect(bike2.organizations.pluck(:id)).to eq([])
          expect {
            put "#{base_url}/#{bike_sticker.code}", params: {bike_sticker: {bike_id: "https://bikeindex.org/bikes/#{bike2.id} "}}
          }.to change(BikeStickerUpdate, :count).by 1
          expect(assigns(:current_organization)&.id).to eq current_organization.id
          expect(flash[:success]).to be_present
          expect(response).to redirect_to bike_path(bike2)
          bike_sticker.reload
          expect(bike_sticker.bike_id).to eq bike2.id
          expect(bike_sticker.previous_bike_id).to eq(bike.id)
          bike2.reload
          expect(bike2.organizations.pluck(:id)).to eq([])
        end
        context "passed code rather than id" do
          it "updates" do
            expect {
              put "#{base_url}/code",
                params: {bike_sticker: {bike_id: bike2.id, code: bike_sticker.code}},
                headers: {"HTTP_REFERER" => bike_path(bike2)}
            }.to change(BikeStickerUpdate, :count).by 1
            expect(assigns(:current_organization)&.id).to eq current_organization.id
            expect(flash[:success]).to be_present
            expect(response).to redirect_to bike_path(bike2)
            bike_sticker.reload
            expect(bike_sticker.bike_id).to eq bike2.id
            expect(bike_sticker.previous_bike_id).to eq bike.id
          end
          context "code blank" do
            it "redirects back" do
              expect {
                put "#{base_url}/code",
                  params: {bike_sticker: {bike_id: bike2.id, code: ""}},
                  headers: {"HTTP_REFERER" => bike_path(bike2)}
              }.to_not change(BikeStickerUpdate, :count)
              expect(assigns(:current_organization)&.id).to eq current_organization.id
              expect(flash[:error]).to be_present
              bike_sticker.reload
              expect(bike_sticker.bike_id).to eq bike.id
            end
          end
          context "incomplete code" do
            let(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_id: bike.id, organization_id: current_organization.id, code: "AA0000151515") }
            it "updates" do
              expect {
                put "#{base_url}/code",
                  params: {bike_sticker: {bike_id: bike2.id, code: "151515"}},
                  headers: {"HTTP_REFERER" => bike_path(bike2)}
              }.to change(BikeStickerUpdate, :count).by 1
              expect(assigns(:current_organization)&.id).to eq current_organization.id
              expect(flash[:success]).to be_present
              expect(response).to redirect_to bike_path(bike2)
              bike_sticker.reload
              expect(bike_sticker.bike_id).to eq bike2.id
            end
          end
        end
        context "non-organization bike_sticker" do
          let(:og_organization) { FactoryBot.create(:organization) }
          let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: og_organization) }
          it "updates" do
            expect(bike_sticker.reload.organization_id).to be_present
            expect(bike_sticker.claimed?).to be_falsey
            expect {
              put "#{base_url}/#{bike_sticker.code}", params: {bike_id: bike2.id, organization_id: current_organization.id},
                headers: {"HTTP_REFERER" => bike_path(bike2)}
            }.to change(BikeStickerUpdate, :count).by 1
            expect(assigns(:current_organization)&.id).to eq current_organization.id
            expect(flash[:success]).to be_present
            expect(response).to redirect_to bike_path(bike2)
            bike_sticker.reload
            expect(bike_sticker.organization_id).to eq og_organization.id
            expect(bike_sticker.secondary_organization_id).to eq current_organization.id
            expect(bike_sticker.bike_id).to eq bike2.id
          end
        end
        context "nil bike_id" do
          it "updates and removes the assignment" do
            og_user_id = bike_sticker.reload.user_id
            expect(bike_sticker.previous_bike_id).to be_blank
            expect {
              put "#{base_url}/#{bike_sticker.code}", params: {bike_id: nil}
            }.to change(BikeStickerUpdate, :count).by 1
            expect(flash[:success]).to be_present
            expect(response).to redirect_to edit_organization_sticker_path(organization_id: current_organization.to_param, id: bike_sticker.code)
            bike_sticker.reload
            expect(bike_sticker.claimed_at).to be_nil
            expect(bike_sticker.bike_id).to be_nil
            expect(bike_sticker.user_id).to eq og_user_id
            expect(bike_sticker.previous_bike_id).to eq(bike.id)
          end
        end
      end
    end
  end
end
