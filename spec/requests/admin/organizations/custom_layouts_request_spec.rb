require "rails_helper"

RSpec.describe Admin::Organizations::CustomLayoutsController, type: :request do
  let(:organization) { FactoryBot.create(:organization) }
  let(:base_url) { "/admin/organizations/#{organization.to_param}/custom_layouts" }
  context "super admin" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      it "redirects" do
        get base_url
        expect(response).to redirect_to(admin_organization_url(organization))
        expect(flash).to be_present
      end
    end
  end

  context "super admin and developer" do
    include_context :request_spec_logged_in_as_superuser
    let(:current_user) { FactoryBot.create(:superuser_developer) }

    describe "index" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe "edit" do
      context "landing_page" do
        it "renders" do
          get "#{base_url}/landing_page/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
          expect(response).to render_template("_landing_page")
        end
      end
      describe "mail_snippets" do
        MailSnippet.organization_snippet_kinds.each do |snippet_kind|
          context snippet_kind do
            it "renders" do
              expect(organization.mail_snippets.count).to eq 0
              get "#{base_url}/#{snippet_kind}/edit"
              expect(response.status).to eq(200)
              expect(response).to render_template(:edit)
              expect(response).to render_template("_mail_snippet")
              organization.reload
              expect(organization.mail_snippets.count).to eq 1
              expect(organization.mail_snippets.where(kind: snippet_kind).count).to eq 1
            end
          end
        end
      end
    end

    describe "organization update" do
      context "landing_page" do
        let(:update) { {landing_html: "<p>html for the landing page</p>"} }
        it "updates and redirects to the landing_page edit" do
          put "#{base_url}/landing_page", params: {organization: update}
          target = edit_admin_organization_custom_layout_path(organization_id: organization.to_param, id: "landing_page")
          expect(response).to redirect_to target
          organization.reload
          expect(organization.landing_html).to eq update[:landing_html]
        end
      end
      context "mail_snippet" do
        let(:snippet_kind) { MailSnippet.organization_snippet_kinds.last }
        let(:mail_snippet) do
          FactoryBot.create(:organization_mail_snippet,
            organization: organization,
            kind: snippet_kind,
            is_enabled: false)
        end
        let(:update_params) do
          {
            mail_snippets_attributes: {
              "0" => {
                id: mail_snippet.id,
                body: "<p>html for snippet 1</p>",
                organization_id: 844, # Ignore
                is_enabled: true
              }
            }
          }
        end
        it "updates the mail snippets" do
          expect(mail_snippet.is_enabled).to be_falsey
          expect {
            put "#{base_url}/#{snippet_kind}", params: {organization: update_params}
          }.to change(MailSnippet, :count).by 0
          target = edit_admin_organization_custom_layout_path(organization_id: organization.to_param, id: snippet_kind)
          expect(response).to redirect_to target
          mail_snippet.reload
          expect(mail_snippet.body).to eq "<p>html for snippet 1</p>"
          expect(mail_snippet.organization).to eq organization
          expect(mail_snippet.is_enabled).to be_truthy
        end
      end
    end
  end
end
