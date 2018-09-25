require "spec_helper"

describe Organized::ExportsController, type: :controller do
  let(:root_path) { organization_bikes_path(organization_id: organization.to_param) }
  let(:exports_root_path) { organization_exports_path(organization_id: organization.to_param) }
  let(:export) { FactoryGirl.create(:export_organization, organization: organization) }

  before { set_current_user(user) if user.present? }

  context "organization without has_bike_codes" do
    let(:organization) { FactoryGirl.create(:organization) }
    context "logged in as organization admin" do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      describe "index" do
        it "redirects" do
          get :index, organization_id: organization.to_param
          expect(response).to redirect_to root_path
          expect(flash[:error]).to be_present
        end
      end

      describe "show" do
        it "redirects" do
          get :show, organization_id: organization.to_param, id: export.id
          expect(response).to redirect_to root_path
          expect(flash[:error]).to be_present
        end
      end
    end

    context "logged in as super admin" do
      let(:user) { FactoryGirl.create(:admin) }
      describe "index" do
        it "renders" do
          get :index, organization_id: organization.to_param
          expect(response).to render_template(:index)
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
        end
      end
    end
  end

  context "organization with csv-exports" do
    let!(:organization) { FactoryGirl.create(:organization) }
    let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
    before { organization.update_column :paid_feature_slugs, ["csv-exports"] } # Stub organization having paid feature

    describe "index" do
      it "renders" do
        expect(export).to be_present # So that we're actually rendering an export
        organization.reload
        expect(organization.paid_for?("csv-exports")).to be_truthy
        get :index, organization_id: organization.to_param
        expect(response.code).to eq("200")
        expect(response).to render_with_layout("application_revised")
        expect(response).to render_template(:index)
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:exports).pluck(:id)).to eq([export.id])
      end
    end

    describe "show" do
      it "renders" do
        get :show, organization_id: organization.to_param, id: export.id
        expect(response.code).to eq("200")
        expect(response).to render_template(:show)
        expect(flash).to_not be_present
      end
      context "not organization export" do
        let(:export) { FactoryGirl.create(:export_organization) }
        it "404s" do
          expect(export.organization.id).to_not eq organization.id
          expect do
            get :show, organization_id: organization.to_param, id: export.id
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    describe "new" do
      it "renders" do
        get :new, organization_id: organization.to_param
        expect(response.code).to eq("200")
        expect(response).to render_template(:new)
        expect(flash).to_not be_present
      end
    end

    describe "destroy" do
      it "renders" do
        expect(export).to be_present
        expect do
          delete :destroy, id: export.id, organization_id: organization.to_param
        end.to change(Export, :count).by(-1)
        expect(response).to redirect_to exports_root_path
        expect(flash[:success]).to be_present
      end
    end

    describe "create" do
      let(:start_at) { 1454925600 }
      let(:valid_attrs) do
        {
          start_at: "2016-02-08 05:00:00",
          end_at: nil,
          timezone: "America/New York",
          headers: %w[link registered_at manufacturer model registered_by]
        }
      end
      it "creates the expected export" do
        expect do
          post :create, export: valid_attrs, organization_id: organization.to_param
        end.to change(Export, :count).by 1
        export = Export.last
        expect(export.kind).to eq "organization"
        expect(export.user).to eq user
        expect(export.headers).to eq valid_attrs[:headers]
        expect(export.start_at.to_i).to be_within(1).of start_at
        expect(OrganizationExportWorker).to have_enqueued_sidekiq_job(export.id)
      end
    end
  end
end
