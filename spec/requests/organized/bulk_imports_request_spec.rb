require "rails_helper"

RSpec.describe Organized::BulkImportsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/bulk_imports" }
  let(:bulk_import) { FactoryBot.create(:bulk_import, organization: current_organization) }
  let(:current_user) { nil }
  let(:file) { Rack::Test::UploadedFile.new(File.open(File.join("public", "import_all_optional_fields.csv"))) }
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
        end
        context "show_bulk_import_impound_bikes" do
          let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, :with_auto_user, enabled_feature_slugs: ["show_bulk_import_impound_bikes"]) }
          it "renders" do
            get base_url
            expect(response.status).to eq(200)
            expect(response).to render_template :index
            expect(assigns(:current_organization)).to eq current_organization
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
