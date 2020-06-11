require "rails_helper"

base_url = "/admin/mail_snippets"
RSpec.describe Admin::MailSnippetsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "edit" do
    let(:mail_snippet) { FactoryBot.create(:mail_snippet) }
    it "renders" do
      get "#{base_url}/#{mail_snippet.id}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end
end
