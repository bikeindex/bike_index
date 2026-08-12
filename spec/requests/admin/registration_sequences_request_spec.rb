require "rails_helper"

RSpec.describe Admin::RegistrationSequencesController, type: :request do
  let(:base_url) { "/admin/registration_sequences" }
  let(:organization) { FactoryBot.create(:organization) }

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser

    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

    describe "index" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:collection).pluck(:id)).to eq([draft.id])
      end

      it "offers to create the template when there isn't one" do
        get base_url
        expect(assigns(:template)).to be_nil
        expect(response.body).to include("Create template")
      end

      context "with a live template and a draft above it" do
        let!(:live_template) { FactoryBot.create(:registration_sequence_template_active, :with_pages) }
        let!(:template_draft) { FactoryBot.create(:registration_sequence_template) }

        it "links the template draft - that's what there is to do to it" do
          get base_url
          expect(assigns(:template)).to eq template_draft
          expect(response.body).to include("Template Draft sequence")
        end
      end

      context "with search_status" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

        it "filters by status" do
          get base_url, params: {search_status: "draft"}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to eq([draft.id])
        end
      end
    end

    describe "edit" do
      it "renders the editor for an organization's draft" do
        get "#{base_url}/#{draft.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
        expect(assigns(:registration_sequence)).to eq draft
      end

      context "template draft" do
        let!(:template) { FactoryBot.create(:registration_sequence_template, :with_pages) }

        it "renders" do
          get "#{base_url}/#{template.id}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
        end
      end

      context "live template" do
        let!(:template) { FactoryBot.create(:registration_sequence_template_active, :with_pages) }

        it "renders, read-only - activation freezes the template too" do
          get "#{base_url}/#{template.id}/edit"
          expect(response.status).to eq(200)
          expect(response.body).to_not include("registration_sequence[faq_url]")
        end
      end

      context "activated sequence" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

        it "renders, read-only" do
          get "#{base_url}/#{active.id}/edit"
          expect(response.status).to eq(200)
          expect(response.body).to_not include("registration_sequence[faq_url]")
        end
      end
    end

    describe "show" do
      it "renders the sequence read-only" do
        get "#{base_url}/#{draft.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(response.body).to_not include("registration_sequence[faq_url]")
      end
    end

    describe "preview" do
      it "renders the preview walk-through" do
        get "#{base_url}/#{draft.id}/preview", params: {page: 2}
        expect(response.status).to eq(200)
        expect(response).to render_template(:preview)
        expect(assigns(:preview_pagy).page).to eq 2
      end
    end

    describe "update" do
      it "updates the settings shared by every page" do
        patch "#{base_url}/#{draft.id}", params: {
          registration_sequence: {faq_url: "https://example.com/faq", acknowledgment_text: "agree to the rules"}
        }
        expect(response).to redirect_to("#{base_url}/#{draft.id}/edit")
        expect(draft.reload.faq_url).to eq "https://example.com/faq"
        expect(draft.acknowledgment_text).to eq "agree to the rules"
      end

      context "activated sequence" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

        it "404s - activation freezes it" do
          patch "#{base_url}/#{active.id}", params: {registration_sequence: {faq_url: "https://example.com/faq"}}
          expect(response.status).to eq(404)
          expect(active.reload.faq_url).to be_blank
        end
      end

      context "activate" do
        it "makes the draft live" do
          patch "#{base_url}/#{draft.id}", params: {activate: true}

          expect(response).to redirect_to("#{base_url}/#{draft.id}")
          expect(draft.reload).to be_active
        end

        context "template draft" do
          let!(:template) { FactoryBot.create(:registration_sequence_template, :with_pages) }
          let!(:previous_template) { FactoryBot.create(:registration_sequence_template_active, :with_pages) }

          it "makes it the live template, archiving the one it supersedes" do
            patch "#{base_url}/#{template.id}", params: {activate: true}

            expect(response).to redirect_to("#{base_url}/#{template.id}")
            expect(RegistrationSequence.active_template).to eq template
            expect(previous_template.reload).to be_archived
          end
        end

        context "draft without pages" do
          let!(:draft) { FactoryBot.create(:registration_sequence, organization:) }

          it "says why it can't go live" do
            patch "#{base_url}/#{draft.id}", params: {activate: true}

            expect(response).to redirect_to("#{base_url}/#{draft.id}/edit")
            expect(flash[:error]).to match(/every page needs/)
            expect(draft.reload).to be_draft
          end
        end

        context "activated sequence" do
          let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

          it "404s" do
            patch "#{base_url}/#{active.id}", params: {activate: true}
            expect(response.status).to eq(404)
          end
        end
      end
    end

    describe "create" do
      it "opens the organization's existing draft" do
        expect { post base_url, params: {organization_id: organization.to_param} }
          .to_not change(RegistrationSequence, :count)
        expect(response).to redirect_to("#{base_url}/#{draft.id}/edit")
      end

      context "no organization" do
        let!(:live_template) { FactoryBot.create(:registration_sequence_template_active, :with_pages) }

        it "opens the template's draft, cloning the live template" do
          expect { post base_url }.to change(RegistrationSequence, :count).by(1)

          template_draft = RegistrationSequence.existing_draft_for(nil)
          expect(response).to redirect_to("#{base_url}/#{template_draft.id}/edit")
          expect(template_draft.registration_sequence_pages.count).to eq 2
        end
      end

      context "organization that doesn't resolve" do
        it "404s rather than opening the template every organization clones" do
          expect { post base_url, params: {organization_id: "#{organization.to_param}-typo"} }
            .to_not change(RegistrationSequence, :count)
          expect(response.status).to eq(404)
        end
      end
    end

    describe "destroy" do
      it "discards the draft and its pages" do
        expect { delete "#{base_url}/#{draft.id}" }
          .to change(RegistrationSequence, :count).by(-1)
          .and change(RegistrationSequencePage, :count).by(-2)
        expect(response).to redirect_to(base_url)
      end

      context "activated sequence" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

        it "404s - only a draft is thrown away" do
          delete "#{base_url}/#{active.id}"
          expect(response.status).to eq(404)
          expect(active.reload).to be_active
        end
      end
    end
  end

  context "logged_in_as_user" do
    include_context :request_spec_logged_in_as_user

    it "blocks non-superusers" do
      get base_url
      expect(response).to_not render_template(:index)
    end
  end
end
