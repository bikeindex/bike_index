require "rails_helper"

RSpec.describe Admin::BulkImportsController, type: :request do
  let(:base_url) { "/admin/bulk_imports/" }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:bulk_import) { FactoryBot.create(:bulk_import) }
    it "renders" do
      get base_url
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end

  describe "show" do
    let!(:bulk_import) { FactoryBot.create(:bulk_import) }
    it "renders" do
      get "#{base_url}/#{bulk_import.id}"
      expect(response).to be_ok
      expect(response).to render_template(:show)
      expect(flash).to_not be_present
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response).to be_ok
      expect(response).to render_template(:new)
      expect(flash).to_not be_present
      bulk_import = assigns(:bulk_import)
      expect(bulk_import.organization_id).to be_nil
      expect(bulk_import.no_notify).to be_falsey
    end
    context "passed params" do
      let(:current_organization) { FactoryBot.create(:organization) }
      it "includes them" do
        get "#{base_url}/new?organization_id=#{current_organization.slug}&no_notify=1"
        expect(response).to be_ok
        expect(response).to render_template(:new)
        expect(flash).to_not be_present
        bulk_import = assigns(:bulk_import)
        expect(bulk_import.organization_id).to eq current_organization.id
        expect(bulk_import.no_notify).to be_truthy
      end
    end
  end

  describe "create" do
    context "valid create" do
      let(:current_organization) { FactoryBot.create(:organization) }
      let(:file) { Rack::Test::UploadedFile.new(File.open(File.join("public", "import_all_optional_fields.csv"))) }
      let(:valid_attrs) { {file: file, organization_id: current_organization.id, no_notify: "1"} }
      it "creates" do
        expect {
          post base_url, params: {bulk_import: valid_attrs}
        }.to change(BulkImport, :count).by 1

        bulk_import = BulkImport.last
        expect(bulk_import.user).to eq current_user
        expect(bulk_import.file_url).to be_present
        expect(bulk_import.progress).to eq "pending"
        expect(bulk_import.organization).to eq current_organization
        expect(bulk_import.send_email).to be_falsey
        expect(bulk_import.no_duplicate).to be_falsey
        expect(bulk_import.kind).to eq "organization_import"
        expect(BulkImportJob).to have_enqueued_sidekiq_job(bulk_import.id)
      end
      context "no_duplicate" do
        it "creates" do
          expect {
            post base_url, params: {bulk_import: valid_attrs.merge(no_duplicate: "1", no_notify: "false")}
          }.to change(BulkImport, :count).by 1

          bulk_import = BulkImport.last
          expect(bulk_import.user).to eq current_user
          expect(bulk_import.file_url).to be_present
          expect(bulk_import.progress).to eq "pending"
          expect(bulk_import.organization).to eq current_organization
          expect(bulk_import.send_email).to be_truthy
          expect(bulk_import.no_duplicate).to be_truthy
          expect(bulk_import.kind).to eq "organization_import"
          expect(BulkImportJob).to have_enqueued_sidekiq_job(bulk_import.id)
        end
      end
    end
  end

  describe "update" do
    let(:bulk_import) { FactoryBot.create(:bulk_import) }
    it "reenqueues" do
      Sidekiq::Job.clear_all
      expect {
        patch "#{base_url}/#{bulk_import.id}", params: {reprocess: true}
      }.to change(BulkImportJob.jobs, :count).by 1
      expect(flash[:success]).to be_present
      expect(BulkImportJob.jobs.map { |j| j["args"] }.flatten).to eq([bulk_import.id])
    end
  end
end
