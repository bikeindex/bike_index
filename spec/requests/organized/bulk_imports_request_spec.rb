require "rails_helper"

RSpec.describe Organized::BulkImportsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/bulk_imports" }
  let(:bulk_import) { FactoryBot.create(:bulk_import, organization: current_organization) }
  let(:current_user) { nil }
  let(:file) { Rack::Test::UploadedFile.new(File.open(File.join("public", "import_all_optional_fields.csv"))) }
  let(:impound_organization) { FactoryBot.create(:organization_with_organization_features, :with_auto_user, enabled_feature_slugs: %w[impound_bikes show_bulk_import_impound_bikes]) }
  before { log_in(current_user) if current_user.present? }

  context "organization without show_bulk_import" do
    let!(:current_organization) { FactoryBot.create(:organization) }
    context "not logged in" do
      it "redirects" do
        expect(current_user).to be_blank
        get base_url
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "logged in as organization admin" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: current_organization) }
      describe "index" do
        it "redirects" do
          get base_url
          expect(response).to redirect_to(organization_root_path)
        end
      end
      describe "new" do
        it "redirects" do
          get "#{base_url}/new"
          expect(response).to redirect_to(organization_root_path)
        end
      end
      describe "show" do
        it "redirects" do
          get "#{base_url}/#{bulk_import.id}"
          expect(response).to redirect_to(organization_root_path)
        end
      end
    end

    context "logged in as super admin" do
      let(:current_user) { FactoryBot.create(:admin) }
      describe "index" do
        it "renders" do
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(assigns(:current_organization)).to eq current_organization
          expect(assigns(:permitted_kinds)).to eq(%w[organization_import impounded])
        end
      end

      describe "new" do
        it "renders" do
          get "#{base_url}/new"
          expect(response.status).to eq(200)
          expect(response).to render_template :new
          expect(assigns(:current_organization)).to eq current_organization
        end
      end
    end
  end

  context "organization with show_bulk_import" do
    let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, :with_auto_user, enabled_feature_slugs: ["show_bulk_import"]) }

    context "logged in as organization member" do
      let(:current_user) { FactoryBot.create(:organization_member, organization: current_organization) }
      describe "index" do
        it "redirects" do
          expect(current_user.authorized?(current_organization)).to be_truthy
          expect(current_organization.show_bulk_import?).to be_truthy
          get base_url
          expect(response).to redirect_to(organization_root_path)
        end
      end
      describe "new" do
        it "redirects" do
          get "#{base_url}/new"
          expect(response).to redirect_to(organization_root_path)
        end
      end
      describe "show" do
        it "redirects" do
          get "#{base_url}/#{bulk_import.id}"
          expect(response).to redirect_to(organization_root_path)
        end
      end
    end

    context "logged_in_as_organization_admin" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: current_organization) }
      describe "index" do
        it "renders" do
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(assigns(:current_organization)).to eq current_organization
          expect(assigns(:permitted_kinds)).to eq(["organization_import"])
        end
        context "ascend" do
          let!(:current_organization) { FactoryBot.create(:organization, pos_kind: "ascend_pos") }
          it "renders" do
            expect(current_organization.reload.ascend_pos?).to be_truthy
            expect(current_organization.show_bulk_import?).to be_truthy
            get base_url
            expect(response.status).to eq(200)
            expect(response).to render_template :index
            expect(assigns(:current_organization)).to eq current_organization
            expect(assigns(:permitted_kinds)).to eq(["ascend"])
          end
        end
        context "show_bulk_import_impound_bikes" do
          let!(:current_organization) { impound_organization }
          it "renders" do
            get base_url
            expect(response.status).to eq(200)
            expect(response).to render_template :index
            expect(assigns(:current_organization)).to eq current_organization
            expect(assigns(:permitted_kinds)).to eq(["impounded"])
          end
        end
      end
      describe "new" do
        it "renders" do
          get "#{base_url}/new"
          expect(response.status).to eq(200)
          expect(response).to render_template :new
          expect(assigns(:current_organization)).to eq current_organization
        end
      end
      describe "show" do
        it "redirects" do
          get "#{base_url}/#{bulk_import.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template :show
        end
        context "not organizations bulk_import" do
          let(:bulk_import) { FactoryBot.create(:bulk_import) }
          it "redirects" do
            expect(bulk_import.organization).to_not eq current_organization
            get "#{base_url}/#{bulk_import.id}"
            expect(response).to redirect_to organization_bulk_imports_path(organization_id: current_organization.to_param)
            expect(flash[:error]).to be_present
          end
        end
      end
      describe "create" do
        context "valid create" do
          let(:bulk_import_params) { {file: file, no_notify: "1", kind: "unorganized"} }
          it "creates" do
            expect {
              post base_url, params: {bulk_import: bulk_import_params}
            }.to change(BulkImport, :count).by 1

            bulk_import = BulkImport.last
            expect(bulk_import.user).to eq current_user
            expect(bulk_import.file_url).to be_present
            expect(bulk_import.progress).to eq "pending"
            expect(bulk_import.organization_id).to eq current_organization.id
            expect(bulk_import.kind).to eq "organization_import" # Because this isn't a permitted kind
            expect(bulk_import.send_email).to be_truthy # Because no_notify isn't permitted here, only in admin
            expect(BulkImportWorker).to have_enqueued_sidekiq_job(bulk_import.id)
          end
          context "impound" do
            let!(:current_organization) { impound_organization }
            let(:file) { Rack::Test::UploadedFile.new(File.open(File.join("public", "import_impounded_only_required.csv"))) }
            let!(:color_purple) { FactoryBot.create(:color, name: "Purple") }
            let!(:color_pink) { FactoryBot.create(:color, name: "Pink") }
            it "imports impounded bikes" do
              Sidekiq::Worker.clear_all
              expect {
                post base_url, params: {bulk_import: {file: file, kind: "impounded"}}
              }.to change(BulkImport, :count).by 1

              bulk_import = BulkImport.last
              expect(bulk_import.user).to eq current_user
              expect(bulk_import.file_url).to be_present
              expect(bulk_import.progress).to eq "pending"
              expect(bulk_import.organization).to eq current_organization
              expect(bulk_import.kind).to eq "impounded"
              expect(BulkImportWorker).to have_enqueued_sidekiq_job(bulk_import.id)

              expect { BulkImportWorker.drain }.to change(Bike, :count).by 2

              bike1 = bulk_import.bikes.reorder(:created_at).first
              expect(bike1.mnfg_name).to eq "Salsa"
              expect(bike1.serial_number).to eq "xyz_test"
              expect(bike1.frame_model).to eq "Warbird"
              expect(bike1.primary_frame_color_id).to eq color_purple.id
              expect(bike1.status).to eq "status_impounded"
              expect(bike1.created_by_notification_or_impounding?).to be_truthy
              expect(bike1.current_impound_record.impounded_at).to be_within(1.day).of Time.parse("2020-10-2")

              bike2 = bulk_import.bikes.reorder(:created_at).last
              expect(bike2.mnfg_name).to eq "Surly"
              expect(bike2.serial_number).to eq "example"
              expect(bike2.frame_model).to eq "Midnight Special"
              expect(bike2.primary_frame_color_id).to eq color_pink.id
              expect(bike2.status).to eq "status_impounded"
              expect(bike2.created_by_notification_or_impounding?).to be_truthy
              expect(bike2.current_impound_record.impounded_at).to be_within(1.day).of Time.parse("2021-01-30")
            end
          end
        end
      end
    end

    describe "create not logged in" do
      context "API create" do
        context "invalid API token" do
          it "returns JSON message" do
            post base_url, params: {file: file}, headers: {"Authorization" => "a9s0dfsdf"}
            expect(response.status).to eq(401)
            expect(json_result["error"]).to be_present
          end
        end
        context "valid" do
          it "returns JSON message" do
            expect(current_user).to be_blank
            expect(current_organization.reload.api_access_approved?).to be_falsey # Not required, as of now
            expect(current_organization.show_bulk_import?).to be_truthy
            expect(current_organization.auto_user).to be_present
            post base_url, params: {file: file}, headers: {"Authorization" => current_organization.access_token}
            expect(response.status).to eq(201)
            expect(json_result["success"]).to be_present

            bulk_import = BulkImport.last
            expect(bulk_import.kind).to eq "organization_import"
            expect(bulk_import.user).to eq current_organization.auto_user
            expect(bulk_import.file_url).to be_present
            expect(bulk_import.progress).to eq "pending"
            expect(bulk_import.organization_id).to eq current_organization.id
            expect(bulk_import.send_email).to be_truthy # Because no_notify isn't permitted here, only in admin
            expect(BulkImportWorker).to have_enqueued_sidekiq_job(bulk_import.id)
          end
        end
        context "ascend token" do
          before { allow(BulkImport).to receive(:ascend_api_token) { "XXXZZZ" } }
          it "returns JSON message" do
            expect {
              post "/o/ascend/bulk_imports", params: {file: file}, headers: {"Authorization" => "a9s0dfsdf"}
            }.to change(BulkImport, :count).by 0
            expect(response.status).to eq(401)
            expect(json_result["error"]).to be_present
          end
          context "valid ascend token" do
            it "returns JSON message" do
              expect {
                post "/o/ascend/bulk_imports", params: {file: file}, headers: {"Authorization" => "XXXZZZ"}
              }.to change(BulkImport, :count).by 1
              expect(response.status).to eq(201)
              expect(json_result["success"]).to be_present

              bulk_import = BulkImport.last
              expect(bulk_import.kind).to eq "ascend"
              expect(bulk_import.import_errors?).to be_blank
              expect(bulk_import.user).to be_blank
              expect(bulk_import.user).to be_blank
              expect(bulk_import.file_url).to be_present
              expect(bulk_import.progress).to eq "pending"
              expect(bulk_import.organization).to be_blank
              expect(bulk_import.send_email).to be_truthy # Because no_notify isn't permitted here, only in admin
              expect(BulkImportWorker).to have_enqueued_sidekiq_job(bulk_import.id)
            end
          end
        end
      end
    end
  end
end
