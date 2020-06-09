require "rails_helper"

base_url = "/admin/ownerships"
RSpec.describe Admin::OwnershipsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:ownership) { FactoryBot.create(:ownership) }
    let(:og_creator) { ownership.creator }

    describe "edit" do
      it "renders" do
        get "#{base_url}/#{ownership.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "update" do
      let(:new_user) { FactoryBot.create(:user_confirmed) }
      let(:update_params) do
        {
          user_email: new_user.email,
          creator_email: current_user.email,
          user_hidden: true,
        }
      end
      it "updates ownership" do
        expect(og_creator).to_not eq current_user
        expect(new_user.confirmed?).to be_truthy
        put "#{base_url}/#{ownership.id}", params: { ownership: update_params }
        expect(response).to redirect_to(edit_admin_ownership_path(ownership))
        expect(flash[:success]).to be_present
        ownership.reload
        expect(ownership.user).to eq new_user
        expect(ownership.user_hidden).to be_truthy
        expect(ownership.creator).to eq(current_user)
      end
      context "user isn't confirmed" do
        let(:new_user) { FactoryBot.create(:user) }
        it "doesn't update" do
          expect(og_creator).to_not eq current_user
          expect(new_user.confirmed?).to be_falsey
          put "#{base_url}/#{ownership.id}", params: { ownership: update_params }
          expect(flash[:error]).to be_present
          ownership.reload
          expect(ownership.user).to be_blank
          expect(ownership.user_hidden).to be_falsey
          expect(ownership.creator).to eq og_creator
        end
      end
    end
  end
end
