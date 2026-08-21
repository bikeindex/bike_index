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
      it "renders in the organization tabs, with the organization's view top right" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(response.body).to include(edit_admin_organization_path(organization, tab: "locations"))
        expect(response.body).to include("href=\"#{organization_emails_path(organization_id: organization.to_param)}\"")
      end
    end

    describe "edit" do
      context "landing_page" do
        it "renders without creating a landing page, and links to the preview" do
          expect(LandingPages::ORGANIZATIONS).to_not include(organization.slug)
          expect {
            get "#{base_url}/landing_page/edit"
          }.to_not change(OrganizationLandingPage, :count)
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
          expect(response.body).to include ">Landing page (html)"
          expect(response.body).to include 'name="organization_landing_page[body]"'
          expect(response.body).to_not match("search_item_type=OrganizationLandingPage")
          expect(response.body).to_not include "button_hover"
          expect(response.body).to include organization_landing_path(organization_id: organization.to_param)
        end

        context "with a routed organization" do
          let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
          let!(:landing_page) { FactoryBot.create(:organization_landing_page, organization:, enabled: true) }

          it "links to the landing page, and says nothing about enabled" do
            expect(LandingPages::ORGANIZATIONS).to include(organization.slug)
            expect(landing_page.enabled_mismatch_error).to be_blank
            get "#{base_url}/landing_page/edit"
            expect(response.status).to eq(200)
            expect(response.body).to include "href=\"#{root_url}#{organization.to_param}\""
            expect(response.body).to_not include organization_landing_path(organization_id: organization.to_param)
            # the agreeing state is the checkbox's job - no alert of any kind
            expect(response.body).to_not include "role=\"alert\""
          end

          context "with the landing page disabled" do
            let!(:landing_page) { FactoryBot.create(:organization_landing_page, organization:) }

            it "alerts the mismatch, and still links to the routed page" do
              get "#{base_url}/landing_page/edit"
              expect(response.status).to eq(200)
              expect(response.body).to include CGI.escapeHTML(landing_page.enabled_mismatch_error)
              expect(response.body).to include "href=\"#{root_url}#{organization.to_param}\""
              expect(response.body).to include 'name="organization_landing_page[enabled]"'
            end
          end
        end

        context "with a landing page" do
          include_context :with_paper_trail
          let!(:landing_page) { FactoryBot.create(:organization_landing_page, organization:) }

          it "links to the version history" do
            get "#{base_url}/landing_page/edit"
            expect(response.status).to eq(200)
            history_path = admin_paper_trail_versions_path(search_item_type: "OrganizationLandingPage",
              search_item_id: landing_page.id, period: "all")
            expect(response.body).to include CGI.escapeHTML(history_path)

            get history_path
            expect(response.status).to eq(200)
            expect(assigns(:collection).map(&:item_id)).to eq([landing_page.id])
          end

          context "framing a register embed with a button color" do
            let(:landing_page) do
              FactoryBot.create(:organization_landing_page, organization:, body: iframe)
            end
            let(:iframe) { "<iframe src='/register/embed?organization_id=x&button=336699'></iframe>" }

            it "recommends the shade step 1 would derive" do
              get "#{base_url}/landing_page/edit"
              expect(response.body).to include "<code>&amp;button_hover=29527a</code>"
            end

            context "one that names its hover too" do
              let(:iframe) { "<iframe src='/register/embed?button=336699&button_hover=29527a'></iframe>" }

              it "says nothing" do
                get "#{base_url}/landing_page/edit"
                expect(response.body).to_not include "<code>&amp;button_hover"
              end
            end
          end
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
              expect(response.body).to include "#{snippet_kind.titleize} snippet"
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
        let(:update) { {body: "<p>html for the landing page</p>"} }
        it "updates and redirects to the landing_page edit" do
          expect {
            put "#{base_url}/landing_page", params: {organization_landing_page: update}
          }.to change(OrganizationLandingPage, :count).by 1
          target = edit_admin_organization_custom_layout_path(organization_id: organization.to_param, id: "landing_page")
          expect(response).to redirect_to target
          expect(organization.reload.organization_landing_page.body).to eq update[:body]
          # the two agree, so no error
          expect(flash[:error]).to be_blank
        end

        context "with a routed organization" do
          let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }

          it "creates the page enabled" do
            expect(LandingPages::ORGANIZATIONS).to include(organization.slug)
            expect {
              put "#{base_url}/landing_page", params: {organization_landing_page: update.merge(enabled: "1")}
            }.to change(OrganizationLandingPage, :count).by 1
            landing_page = organization.reload.organization_landing_page
            expect(landing_page.enabled).to be_truthy
            expect(landing_page.enabled_mismatch_error).to be_blank
          end
        end

        context "when enabled disagrees with ORGANIZATIONS_WITH_LANDING_PAGES" do
          let!(:landing_page) { FactoryBot.create(:organization_landing_page, organization:, enabled: true) }

          it "saves, and the edit page alerts the mismatch" do
            put "#{base_url}/landing_page", params: {organization_landing_page: update}
            expect(landing_page.reload.body).to eq update[:body]
            expect(flash[:success]).to be_present
            expect(flash[:error]).to be_blank

            follow_redirect!
            expect(response.body).to include CGI.escapeHTML(landing_page.enabled_mismatch_error)
          end

          it "resolves the mismatch when enabled is unchecked" do
            put "#{base_url}/landing_page", params: {organization_landing_page: update.merge(enabled: "0")}
            expect(landing_page.reload.enabled).to be_falsey
            expect(landing_page.enabled_mismatch_error).to be_blank

            follow_redirect!
            expect(response.body).to_not include "ORGANIZATIONS_WITH_LANDING_PAGES"
          end
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
