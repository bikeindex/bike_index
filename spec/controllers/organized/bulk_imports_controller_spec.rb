require "spec_helper"

describe Organized::BulkImportsController, type: :controller do
  let(:root_path) { organization_bikes_path(organization_id: organization.to_param) }
  let(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization) }

  before { set_current_user(user) }

  context "organization without show_bulk_import" do
    let!(:organization) { FactoryGirl.create(:organization) }
    context "logged in as organization admin" do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      describe "index" do
        it "redirects" do
          get :index, organization_id: organization.to_param
          expect(response).to redirect_to root_path
        end
      end
      describe "new" do
        it "redirects" do
          get :new, organization_id: organization.to_param
          expect(response).to redirect_to root_path
        end
      end
      describe "show" do
        it "redirects" do
          get :show, id: bulk_import.id, organization_id: organization.to_param
          expect(response).to redirect_to root_path
        end
      end
    end

    context "logged in as super admin" do
      let(:user) { FactoryGirl.create(:admin) }
      describe "index" do
        it "renders" do
          get :index, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
        end
      end

      describe "new" do
        it "renders" do
          get :new, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :new
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
        end
      end
    end
  end

  context "organization with show_bulk_import" do
    let!(:organization) { FactoryGirl.create(:organization, show_bulk_import: true) }
    context "logged in as organization member" do
      let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
      describe "index" do
        it "redirects" do
          get :index, organization_id: organization.to_param
          expect(response).to redirect_to root_path
        end
      end
      describe "new" do
        it "redirects" do
          get :new, organization_id: organization.to_param
          expect(response).to redirect_to root_path
        end
      end
      describe "show" do
        it "redirects" do
          get :show, id: bulk_import.id, organization_id: organization.to_param
          expect(response).to redirect_to root_path
        end
      end
    end
    context "logged_in_as_organization_admin" do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      describe "index" do
        it "renders" do
          get :index, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
        end
      end

      describe "new" do
        it "renders" do
          get :new, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :new
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
        end
      end

      describe "show" do
        it "redirects" do
          get :show, id: bulk_import.id, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :show
          expect(response).to render_with_layout("application_revised")
        end
        context "not organizations bulk_import" do
          let(:bulk_import) { FactoryGirl.create(:bulk_import) }
          it "redirects" do
            expect(bulk_import.organization).to_not eq organization
            get :show, id: bulk_import.id, organization_id: organization.to_param
            expect(response).to redirect_to organization_bulk_imports_path(organization_id: organization.to_param)
            expect(flash[:error]).to be_present
          end
        end
      end
    end
  end
end
