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

  def parsed_body
    Capybara.string(response.body)
  end

  describe "new" do
    it "renders the kind and organization comboboxes" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)

      expect(parsed_body).to have_css("fieldset.hw-combobox[data-controller='hw-combobox']", count: 2)
      expect(parsed_body).to have_css("input[type=hidden][name='mail_snippet[kind]']", visible: :all)
      expect(parsed_body).to have_css("input[type=hidden][name='mail_snippet[organization_id]']", visible: :all)
    end
  end

  describe "edit" do
    let(:mail_snippet) { FactoryBot.create(:mail_snippet, kind: :custom) }

    it "renders with the kind combobox prefilled" do
      get "#{base_url}/#{mail_snippet.id}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)

      kind_display = "#{MailSnippet.kind_humanized("custom")} - in #{MailSnippet.organization_email_for("custom")} emails"
      expect(parsed_body).to have_css("[data-hw-combobox-prefilled-display-value='#{kind_display}']")
      expect(parsed_body).to have_css("input[type=hidden][name='mail_snippet[kind]'][value='#{MailSnippet::KIND_ENUM[:custom]}']", visible: :all)
    end

    context "with a stolen_notification_oauth snippet" do
      let(:mail_snippet) { FactoryBot.create(:mail_snippet, kind: :stolen_notification_oauth) }

      it "renders the doorkeeper_app_id combobox" do
        get "#{base_url}/#{mail_snippet.id}/edit"
        expect(response.status).to eq(200)
        expect(parsed_body).to have_css("input[type=hidden][name='mail_snippet[doorkeeper_app_id]']", visible: :all)
      end
    end
  end

  describe "update" do
    include_context :with_paper_trail

    let!(:mail_snippet) { FactoryBot.create(:mail_snippet) }
    it "updates" do
      patch "#{base_url}/#{mail_snippet.id}", params: {mail_snippet: valid_params}

      expect(response).to redirect_to(edit_admin_mail_snippet_path(mail_snippet.to_param))
      expect(flash[:errors]).to be_blank
      mail_snippet.reload
      expect(mail_snippet).to have_attributes valid_params
      version = mail_snippet.versions.last
      expect(version.event).to eq "update"
      expect(version.whodunnit).to eq current_user.id.to_s
    end
  end
end
