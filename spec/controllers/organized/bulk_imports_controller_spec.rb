require "spec_helper"

describe Organized::BulkImportsController, type: :controller do
  let(:root_path) { organization_bikes_path(organization_id: organization.to_param) }
  let(:bulk_import) { FactoryBot.create(:bulk_import, organization: organization) }

  before { set_current_user(user) if user.present? }

  context "organization without show_bulk_import" do
    let!(:organization) { FactoryBot.create(:organization) }
    context "not logged in" do
      let(:user) { nil }
      it "redirects" do
        get :index, organization_id: organization.to_param
        expect(response).to redirect_to root_path
      end
    end

    context "logged in as organization admin" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
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
      let(:user) { FactoryBot.create(:admin) }
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
    let!(:organization) { FactoryBot.create(:organization) }
    before { organization.update_column :paid_feature_slugs, ["show_bulk_import"] } # Stub organization having paid feature

    context "logged in as organization member" do
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
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
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
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
          let(:bulk_import) { FactoryBot.create(:bulk_import) }
          it "redirects" do
            expect(bulk_import.organization).to_not eq organization
            get :show, id: bulk_import.id, organization_id: organization.to_param
            expect(response).to redirect_to organization_bulk_imports_path(organization_id: organization.to_param)
            expect(flash[:error]).to be_present
          end
        end
      end
      describe "create" do
        let(:file) { Rack::Test::UploadedFile.new(File.open(File.join("public", "import_all_optional_fields.csv"))) }
        context "valid create" do
          let(:bulk_import_params) { { file: file, organization_id: 392, no_notify: "1" } }
          it "creates" do
            expect do
              post :create, organization_id: organization.to_param, bulk_import: bulk_import_params
            end.to change(BulkImport, :count).by 1

            bulk_import = BulkImport.last
            expect(bulk_import.user).to eq user
            expect(bulk_import.file_url).to be_present
            expect(bulk_import.progress).to eq "pending"
            expect(bulk_import.organization).to eq organization
            expect(bulk_import.send_email).to be_truthy # Because no_notify isn't permitted here, only in admin
            expect(BulkImportWorker).to have_enqueued_sidekiq_job(bulk_import.id)
          end
        end
        context "API create" do
          let(:organization) { FactoryBot.create(:organization_with_auto_user, api_access_approved: true) }
          let(:user) { nil }
          context "invalid API token" do
            it "returns JSON message" do
              request.headers["Authorization"] = "a9s0dfsdf" # Rspec doesn't support headers key here. TODO: Rails 5 update
              post :create, organization_id: organization.to_param, file: file
              expect(response.status).to eq(401)
              expect(json_result["error"]).to be_present
            end
          end
          context "valid" do
            it "returns JSON message" do
              expect(organization.auto_user).to be_present
              request.headers["Authorization"] = organization.access_token # Rspec doesn't support headers key here. TODO: Rails 5 update
              post :create, organization_id: organization.to_param, file: file
              expect(response.status).to eq(201)
              expect(json_result["success"]).to be_present

              bulk_import = BulkImport.last
              expect(bulk_import.is_ascend).to be_falsey
              expect(bulk_import.user).to eq organization.auto_user
              expect(bulk_import.file_url).to be_present
              expect(bulk_import.progress).to eq "pending"
              expect(bulk_import.organization).to eq organization
              expect(bulk_import.send_email).to be_truthy # Because no_notify isn't permitted here, only in admin
              expect(BulkImportWorker).to have_enqueued_sidekiq_job(bulk_import.id)
            end
          end
          context "ascend token" do
            before { allow(BulkImport).to receive(:ascend_api_token) { "XXXZZZ" } }
            it "returns JSON message" do
              request.headers["Authorization"] = "a9s0dfsdf" # Rspec doesn't support headers key here. TODO: Rails 5 update
              expect do
                post :create, organization_id: "ascend", file: file
              end.to change(BulkImport, :count).by 0
              expect(response.status).to eq(401)
              expect(json_result["error"]).to be_present
            end
            context "valid ascend token" do
              it "returns JSON message" do
                request.headers["Authorization"] = "XXXZZZ" # Rspec doesn't support headers key here. TODO: Rails 5 update
                expect do
                  post :create, organization_id: "ascend", file: file
                end.to change(BulkImport, :count).by 1
                expect(response.status).to eq(201)
                expect(json_result["success"]).to be_present

                bulk_import = BulkImport.last
                expect(bulk_import.is_ascend).to be_truthy
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
end
