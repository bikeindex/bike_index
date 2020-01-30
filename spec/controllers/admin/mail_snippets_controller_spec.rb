require "rails_helper"

RSpec.describe Admin::MailSnippetsController, type: :controller do
  include_context :logged_in_as_super_admin

  describe "index" do
    it "renders without_organizations mail_snippets" do
      FactoryBot.create(:organization_mail_snippet)
      mail_snippet = FactoryBot.create(:mail_snippet)
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:mail_snippets)).to eq([mail_snippet])
    end
  end

  describe "edit" do
    context "organization_mail_snippet" do
      let(:mail_snippet) { FactoryBot.create(:organization_mail_snippet) }
      it "redirects" do
        expect do
          get :edit, params: { id: mail_snippet.id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context "non organized" do
      let(:mail_snippet) { FactoryBot.create(:mail_snippet) }
      it "renders" do
        get :edit, params: { id: mail_snippet.id }
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
  end
end
