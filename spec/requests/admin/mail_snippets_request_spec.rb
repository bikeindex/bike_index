require "rails_helper"

base_url = "/admin/mail_snippets"
RSpec.describe Admin::MailSnippetsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let(:organization) { FactoryBot.create(:organization) }
  let(:valid_params) do
    {
      kind: MailSnippet.kinds.first,
      subject: "Mail Snippetted subject",
      body: "<p>Something</p>",
      organization_id: organization.id,
      is_enabled: false
    }
  end

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

  describe "update" do
    let!(:mail_snippet) { FactoryBot.create(:mail_snippet) }
    it "updates" do
      patch "#{base_url}/#{mail_snippet.id}", params: {mail_snippet: valid_params}

      expect(response).to redirect_to(edit_admin_mail_snippet_path(mail_snippet.to_param))
      expect(flash[:errors]).to be_blank
      mail_snippet.reload
      expect(mail_snippet).to have_attributes valid_params
    end
  end
end
