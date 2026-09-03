require "rails_helper"

RSpec.describe Admin::RegistrationSequencePagesController, type: :request do
  let(:base_url) { "/admin/registration_sequences/#{template.id}/pages" }
  let(:member_url) { "/admin/registration_sequence_pages" }
  let(:sequence_path) { "/admin/registration_sequences/#{template.id}/edit" }
  let!(:template) { FactoryBot.create(:registration_sequence_template, :with_pages) }

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "new" do
      it "renders a blank page form without persisting one" do
        expect { get "#{base_url}/new" }.to_not change(RegistrationSequencePage, :count)
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "create" do
      it "adds the page and returns to the sequence" do
        expect {
          post base_url, params: {registration_sequence_page: {title: "Storage", body: "<ul><li>Store safely</li></ul>"}}
        }.to change { template.registration_sequence_pages.count }.by(1)
        expect(response).to redirect_to(sequence_path)
        expect(template.registration_sequence_pages.reorder(:id).last.title).to eq("Storage")
      end

      it "re-renders without persisting an incomplete page" do
        expect { post base_url, params: {registration_sequence_page: {title: ""}} }
          .to_not change(RegistrationSequencePage, :count)
        expect(response.status).to eq(422)
        expect(response).to render_template(:edit)
      end
    end

    describe "edit" do
      let(:page) { template.registration_sequence_pages.first }

      it "renders" do
        get "#{member_url}/#{page.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "update" do
      let(:page) { template.registration_sequence_pages.first }

      it "updates the page and returns to its preview" do
        patch "#{member_url}/#{page.id}", params: {
          registration_sequence_page: {title: "Batteries", subtitle: "Charge safely",
                                       body: "<ul><li>first</li></ul>", organization_specific: "1"}
        }
        expect(response).to redirect_to("#{member_url}/#{page.id}/edit")
        expect(page.reload.title).to eq("Batteries")
        expect(page.subtitle).to eq("Charge safely")
        expect(page.organization_specific).to be_truthy
      end

      it "moves the page to a position and re-sequences" do
        ids = template.registration_sequence_pages.pluck(:id)
        patch "#{member_url}/#{ids.last}", params: {position: 0}
        expect(response.status).to eq(200)
        expect(template.registration_sequence_pages.reload.pluck(:id)).to eq([ids.last] + ids[0...-1])
      end
    end

    describe "destroy" do
      let!(:page) { template.registration_sequence_pages.first }

      it "removes the page" do
        expect { delete "#{member_url}/#{page.id}" }.to change { template.registration_sequence_pages.count }.by(-1)
        expect(response).to redirect_to(sequence_path)
      end
    end

    describe "an organization's draft" do
      let(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: FactoryBot.create(:organization)) }

      it "edits the draft's pages too" do
        patch "#{member_url}/#{draft.registration_sequence_pages.first.id}", params: {
          registration_sequence_page: {title: "Campus rules", body: "<ul><li>first</li></ul>"}
        }
        expect(draft.registration_sequence_pages.first.reload.title).to eq("Campus rules")
      end
    end

    context "activated sequence" do
      let(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: FactoryBot.create(:organization)) }

      it "404s on create - activation freezes the pages" do
        post "/admin/registration_sequences/#{active.id}/pages"
        expect(response.status).to eq(404)
      end

      it "404s when editing one of its pages" do
        get "#{member_url}/#{active.registration_sequence_pages.first.id}/edit"
        expect(response.status).to eq(404)
      end
    end
  end

  context "logged_in_as_user" do
    include_context :request_spec_logged_in_as_user

    it "blocks non-superusers" do
      get "#{base_url}/new"
      expect(response).to_not render_template(:edit)
    end
  end
end
