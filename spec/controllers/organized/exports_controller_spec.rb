require "spec_helper"

describe Organized::ExportsController, type: :controller do
  let(:root_path) { organization_bikes_path(organization_id: organization.to_param) }
  let(:exports_root_path) { organization_exports_path(organization_id: organization.to_param) }
  let(:export) { FactoryBot.create(:export_organization, organization: organization) }

  before { set_current_user(user) if user.present? }

  context "organization without has_bike_codes" do
    let(:organization) { FactoryBot.create(:organization) }
    context "logged in as organization admin" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
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
      let(:user) { FactoryBot.create(:admin) }
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

  context "organization with csv_exports" do
    let!(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    before { organization.update_column :paid_feature_slugs, ["csv_exports"] } # Stub organization having paid feature

    describe "index" do
      it "renders" do
        expect(export).to be_present # So that we're actually rendering an export
        organization.reload
        expect(organization.paid_for?("csv_exports")).to be_truthy
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
        let(:export) { FactoryBot.create(:export_organization) }
        it "404s" do
          expect(export.organization.id).to_not eq organization.id
          expect do
            get :show, organization_id: organization.to_param, id: export.id
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
      context "avery_export" do
        let(:target_redirect_url) { "https://avery.com?mergeDataURL=https%3A%2F%2Ffiles.bikeindex.org%2Fexports%2F820181214ccc.xlsx" }
        it "redirects" do
          ENV["AVERY_EXPORT_URL"] = "https://avery.com?mergeDataURL="
          allow_any_instance_of(Export).to receive(:file_url) { "https://files.bikeindex.org/exports/820181214ccc.xlsx" }
          export.update_attributes(progress: "finished", options: export.options.merge(avery_export: true))
          get :show, organization_id: organization.to_param, id: export.id, avery_redirect: true
          expect(response).to redirect_to target_redirect_url
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
      context "organization has all feature slugs" do
        it "renders still" do
          organization.update_column :paid_feature_slugs, ["csv_exports"] + PaidFeature::REG_FIELDS # Stub organization having features
          get :new, organization_id: organization.to_param
          expect(response.code).to eq("200")
          expect(response).to render_template(:new)
          expect(flash).to_not be_present
        end
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
          start_at: "2016-02-08 02:00:00",
          end_at: nil,
          file_format: "xlsx",
          timezone: "America/Los Angeles",
          headers: %w[link registered_at manufacturer model registered_by]
        }
      end
      it "creates the expected export" do
        expect do
          post :create, export: valid_attrs, organization_id: organization.to_param
        end.to change(Export, :count).by 1
        expect(response).to redirect_to organization_exports_path(organization_id: organization.to_param)
        export = Export.last
        expect(export.kind).to eq "organization"
        expect(export.file_format).to eq "xlsx"
        expect(export.user).to eq user
        expect(export.headers).to eq valid_attrs[:headers]
        expect(export.start_at.to_i).to be_within(1).of start_at
        expect(export.end_at).to_not be_present
        expect(OrganizationExportWorker).to have_enqueued_sidekiq_job(export.id)
      end
      context "organization with avery export, non-avery export" do
        before { organization.update_column :paid_feature_slugs, %w[csv_exports avery_export] } # Stub organization having features
        let(:export_params) { valid_attrs.merge(file_format: "csv", avery_export: "0", end_at: "2016-02-10 02:00:00") }
        it "creates a non-avery export" do
          expect(organization.paid_for?("avery_export")).to be_truthy
          expect do
            post :create, export: export_params.merge(bike_code_start: 1), organization_id: organization.to_param
          end.to change(Export, :count).by 1
          expect(response).to redirect_to organization_exports_path(organization_id: organization.to_param)
          export = Export.last
          expect(export.kind).to eq "organization"
          expect(export.file_format).to eq "csv"
          expect(export.user).to eq user
          expect(export.headers).to eq valid_attrs[:headers]
          expect(export.start_at.to_i).to be_within(1).of start_at
          expect(export.end_at.to_i).to be_within(1).of start_at + 2.days.to_i
          expect(export.bike_code_start).to be_nil
          expect(OrganizationExportWorker).to have_enqueued_sidekiq_job(export.id)
          expect(export.avery_export?).to be_falsey
        end
      end
      context "avery export" do
        let(:avery_params) { valid_attrs.merge(end_at: "2016-03-08 02:00:00", avery_export: true, bike_code_start: "a221C ") }
        it "fails" do
          expect do
            post :create, export: avery_params, organization_id: organization.to_param
          end.to_not change(Export, :count)
          expect(flash[:error]).to be_present
        end
        context "organization with avery export" do
          let(:end_at) { 1457431200 }
          before { organization.update_column :paid_feature_slugs, %w[csv_exports avery_export] } # Stub organization having features
          it "makes the avery export" do
            expect do
              post :create, export: avery_params, organization_id: organization.to_param
            end.to change(Export, :count).by 1
            export = Export.last
            expect(response).to redirect_to organization_export_path(organization_id: organization.to_param, id: export.id, avery_redirect: true)
            expect(export.kind).to eq "organization"
            expect(export.file_format).to eq "xlsx"
            expect(export.user).to eq user
            expect(export.headers).to eq Export::AVERY_HEADERS
            expect(export.avery_export?).to be_truthy
            expect(export.start_at.to_i).to be_within(1).of start_at
            expect(export.end_at.to_i).to be_within(1).of end_at
            expect(export.bike_code_start).to eq "A221C"
            expect(OrganizationExportWorker).to have_enqueued_sidekiq_job(export.id)
          end
        end
      end
    end
  end
end
