require "rails_helper"

RSpec.describe Admin::RegistrationSequencesController, type: :request do
  let(:base_url) { "/admin/registration_sequences" }
  let(:organization) { FactoryBot.create(:organization) }

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser

    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

    describe "index" do
      it "renders the pending drafts" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:registration_sequences).pluck(:id)).to eq([draft.id])
      end
    end

    describe "show" do
      it "renders" do
        get "#{base_url}/#{draft.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
      end
    end

    describe "update" do
      let!(:live) { FactoryBot.create(:registration_sequence_live, :with_pages, organization:) }

      it "makes the draft live and archives the prior live" do
        patch "#{base_url}/#{draft.id}"
        expect(response).to redirect_to(admin_registration_sequences_path)
        expect(draft.reload).to be_live
        expect(draft.approved_by).to eq(current_user)
        expect(live.reload).to be_archived
        expect(organization.registration_sequences.live.count).to eq(1)
      end
    end
  end

  context "logged_in_as_user" do
    include_context :request_spec_logged_in_as_user
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

    it "blocks non-superusers" do
      get base_url
      expect(response).to_not render_template(:index)
      patch "#{base_url}/#{draft.id}"
      expect(draft.reload).to be_draft
    end
  end
end
