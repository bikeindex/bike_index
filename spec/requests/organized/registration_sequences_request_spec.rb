require "rails_helper"

RSpec.describe Organized::RegistrationSequencesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registration_sequences" }

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    before { current_organization.update_columns(enabled_feature_slugs: %w[registration_sequences registration_sequences_edit]) }

    describe "index" do
      it "renders without creating a draft" do
        expect { get base_url }.to_not change(RegistrationSequence, :count)
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(response.body).to include("There is no active registration sequence")
        expect(response.body).to include("You don't have a draft sequence")
        # Nothing to copy yet, so the button starts a fresh one
        expect(response.body).to include("Create a sequence")
      end

      context "with a draft" do
        let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

        it "lists its pages, and offers to resume editing or discard it" do
          get base_url
          expect(response.body).to include(draft.registration_sequence_pages.first.title)
          # Read-only, the same as the active version - it's edited on its own screen
          expect(response.body).to_not include("data-controller=\"sortable\"")
          expect(response.body).to include(">Edit<")
          expect(response.body).to include("Discard draft")
          # Turbo Drive is off app-wide, so the confirm has to be the form's own
          expect(response.body).to include("onsubmit=\"return confirm(")
        end
      end

      context "with an active sequence" do
        # Built as a draft and activated, the way an organization gets one
        let!(:active) do
          FactoryBot.create(:registration_sequence, organization: current_organization).tap do |sequence|
            sequence.registration_sequence_pages.create!(title: "Batteries & charging",
              body: "<ul><li>Charge with the manufacturer's charger</li></ul>")
            sequence.make_active!
          end
        end

        it "lists what registrants are actually agreeing to" do
          get base_url
          expect(response.status).to eq(200)
          expect(response.body).to include("This is the active version your registrants see")
          expect(response.body).to include("Batteries &amp; charging")
          expect(response.body).to include("Charge with the manufacturer's charger")
          # No draft yet, so editing starts from a copy of the live sequence
          expect(response.body).to include("Copy current sequence and edit")
          # Frozen, so no editing affordances on it
          expect(response.body).to_not include("data-sortable-target=\"item\"")
        end
      end
    end

    describe "create" do
      it "builds a draft from the template and redirects to the management page" do
        expect {
          post base_url
        }.to change { current_organization.registration_sequences.draft.count }.by(1)
        draft = current_organization.registration_sequences.draft.first
        expect(response).to redirect_to(edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id))
      end
    end

    describe "show" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

      it "renders, titled for a draft" do
        get "#{base_url}/#{draft.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(response.body).to match(%r{Previewing.{0,40}<strong>Draft</strong>.{0,20}registration sequence}m)
        # Back link to the index, next to the pagination
        expect(response.body).to include(">← Registration Sequences</a>")
      end

      it "pages through the rules, then the review, with pagination" do
        get "#{base_url}/#{draft.id}?page=1"
        expect(response.body).to include("Continue")
        expect(response.body).to include("page=2") # pagination links to the next screen

        get "#{base_url}/#{draft.id}?page=99" # clamped to the review screen
        expect(response.body).to include("almost done")
      end

      context "with an active (non-draft) sequence" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }

        it "renders the preview, titled live" do
          get "#{base_url}/#{active.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(response.body).to match(%r{Previewing.{0,40}<strong>Current</strong>.{0,20}registration sequence}m)
        end
      end
    end

    describe "edit" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

      it "renders the draft management view" do
        get "#{base_url}/#{draft.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end

      it "404s for a non-draft sequence" do
        active = FactoryBot.create(:registration_sequence_active, organization: current_organization)
        get "#{base_url}/#{active.id}/edit"
        expect(response.status).to eq(404)
      end
    end

    describe "update" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

      it "saves the settings shared by every page" do
        patch "#{base_url}/#{draft.id}", params: {registration_sequence: {faq_url: "https://example.com/faq",
                                                                          acknowledgment_text: "agree to all of it"}}
        expect(response).to redirect_to(edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id))
        expect(draft.reload).to have_attributes(faq_url: "https://example.com/faq",
          acknowledgment: "agree to all of it")
      end

      it "404s for another organization's draft" do
        other = FactoryBot.create(:registration_sequence)
        patch "#{base_url}/#{other.id}", params: {registration_sequence: {faq_url: "https://example.com"}}
        expect(response.status).to eq(404)
      end
    end

    describe "destroy" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

      it "discards the draft and its pages" do
        expect { delete "#{base_url}/#{draft.id}" }.to change(RegistrationSequence, :count).by(-1)
        expect(response).to redirect_to(base_url)
        expect(RegistrationSequence.with_deleted.find_by(id: draft.id)).to be_nil
      end

      it "404s for a non-draft sequence" do
        active = FactoryBot.create(:registration_sequence_active, organization: current_organization)
        expect { delete "#{base_url}/#{active.id}" }.to_not change(RegistrationSequence, :count)
        expect(response.status).to eq(404)
      end
    end
  end

  context "logged_in_as_organization_admin with registration_sequences but not registration_sequences_edit" do
    include_context :request_spec_logged_in_as_organization_admin
    before { current_organization.update_columns(enabled_feature_slugs: ["registration_sequences"]) }

    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }
    let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }

    it "renders the index without any sign of the draft" do
      get base_url
      expect(response.status).to eq(200)
      expect(response.body).to include("This is the active version your registrants see")
      expect(response.body).to include(active.registration_sequence_pages.first.title)
      # The whole draft section is gone - not an empty-state, not a read-only listing
      expect(response.body).to_not include(">Draft</h2>")
      expect(response.body).to_not include("You don't have a draft sequence")
      expect(response.body).to_not include(">Edit<")
      expect(response.body).to_not include("Discard draft")
    end

    it "renders the preview of the active sequence" do
      get "#{base_url}/#{active.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end

    it "blocks previewing the draft" do
      get "#{base_url}/#{draft.id}"
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end

    it "blocks opening a draft" do
      expect { post base_url }.to_not change(RegistrationSequence, :count)
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end

    it "blocks editing, updating and discarding" do
      get "#{base_url}/#{draft.id}/edit"
      expect(response).to redirect_to(organization_root_path)

      patch "#{base_url}/#{draft.id}", params: {registration_sequence: {faq_url: "https://example.com/faq"}}
      expect(response).to redirect_to(organization_root_path)
      expect(draft.reload.faq_url).to_not eq("https://example.com/faq")

      expect { delete "#{base_url}/#{draft.id}" }.to_not change(RegistrationSequence, :count)
      expect(response).to redirect_to(organization_root_path)
    end
  end

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user

    it "blocks non-admins" do
      get base_url
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end
  end

  context "logged_in_as_organization_admin without the feature" do
    include_context :request_spec_logged_in_as_organization_admin

    it "blocks the org admin" do
      get base_url
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end
  end

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:current_organization) { FactoryBot.create(:organization) }

    it "renders even without the feature" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
