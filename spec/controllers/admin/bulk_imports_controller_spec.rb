require "spec_helper"

describe Admin::BulkImportsController do
  let(:user) { FactoryGirl.create(:admin) }
  before do
    set_current_user(user)
  end

  describe "index" do
    let!(:bulk_import) { FactoryGirl.create(:bulk_import) }
    it "renders" do
      get :index
      expect(response).to be_success
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end

  describe "show" do
    let!(:bulk_import) { FactoryGirl.create(:bulk_import) }
    it "renders" do
      get :show, id: bulk_import.id
      expect(response).to be_success
      expect(response).to render_template(:show)
      expect(flash).to_not be_present
    end
  end

  describe "new" do
    it "renders" do
      get :new
      expect(response).to be_success
      expect(response).to render_template(:new)
      expect(flash).to_not be_present
    end
  end

  describe "create" do
    context "valid create" do
      let(:organization) { FactoryGirl.create(:organization) }
      let(:valid_attrs) { { file_url: "https://something.com", organization_id: organization.id, no_notify: "1" } }
      it "creates" do
        expect do
          post :create, bulk_import: valid_attrs
        end.to change(BulkImport, :count).by 1

        bulk_import = BulkImport.last
        expect(bulk_import.user).to eq user
        expect(bulk_import.file_url).to eq valid_attrs[:file_url]
        expect(bulk_import.progress).to eq "pending"
        expect(bulk_import.organization).to eq organization
        expect(bulk_import.send_email).to be_falsey
        expect(BulkImportWorker).to have_enqueued_sidekiq_job(bulk_import.id)
      end
    end
  end
end
