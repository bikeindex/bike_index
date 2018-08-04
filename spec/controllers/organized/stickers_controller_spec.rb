require "spec_helper"

describe Organized::StickersController, type: :controller do
  let(:root_path) { organization_bikes_path(organization_id: organization.to_param) }
  let(:bike_code) { FactoryGirl.create(:bike_code, organization: organization) }

  before { set_current_user(user) if user.present? }

  context "organization without has_bike_codes" do
    let!(:organization) { FactoryGirl.create(:organization) }
    context "logged in as organization admin" do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      describe "index" do
        it "redirects" do
          get :index, organization_id: organization.to_param
          expect(response).to redirect_to root_path
        end
      end
    end
    context "logged in as super admin" do
      let(:user) { FactoryGirl.create(:admin) }
      describe "index" do
        it "redirects" do
          get :index, organization_id: organization.to_param
          expect(response).to render_template(:index)
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
        end
      end
    end
  end

  context "organization with has_bike_codes" do
    let!(:organization) { FactoryGirl.create(:organization, has_bike_codes: true) }
    let!(:bike_code) { FactoryGirl.create(:bike_code, organization: organization, code: "partee") }
    context "logged in as organization member" do
      let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
      describe "index" do
        it "renders" do
          get :index, organization_id: organization.to_param
          expect(response).to render_template(:index)
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
          expect(assigns(:bike_codes).pluck(:id)).to eq([bike_code.id])
        end
        context "with search" do
          let!(:bike_code_claimed) { FactoryGirl.create(:bike_code, organization: organization, code: "part") }
          let!(:bike_code_no_org) { FactoryGirl.create(:bike_code, code: "part") }
          before { bike_code_claimed.claim(user, FactoryGirl.create(:bike).id) }
          it "renders" do
            get :index, organization_id: organization.to_param, claimedness: "unclaimed", query: "part"
            expect(response).to render_template(:index)
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:bike_codes).pluck(:id)).to eq([bike_code.id])
          end
        end
      end

      describe "edit" do
        it "renders" do
          get :edit, id: bike_code.code, organization_id: organization.to_param
          expect(response).to render_template(:edit)
          expect(assigns(:current_organization)).to eq organization
        end
      end
    end
  end
end
