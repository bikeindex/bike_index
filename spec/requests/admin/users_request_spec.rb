require "rails_helper"

RSpec.describe Admin::UsersController, type: :request do
  base_url = "/admin/users/"
  include_context :request_spec_logged_in_as_superuser
  let(:user_subject) { FactoryBot.create(:user) }

  describe "index" do
    it "renders" do
      expect(user_subject).to be_present
      get "#{base_url}?query=something" # Test to make sure we're dealing with admin_text_search correctly
      expect(response).to render_template :index
    end
  end

  describe "show" do
    it "links to edit" do
      get "#{base_url}/#{user_subject.username}"
      expect(response).to redirect_to(edit_admin_user_path(user_subject.id))
    end
  end

  describe "edit" do
    context "user doesn't exist" do
      it "404s" do
        expect {
          get "#{base_url}/STUFFFFFF/edit"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context "username" do
      it "shows the edit page if the user exists" do
        get "#{base_url}/#{user_subject.username}/edit"
        expect(response).to redirect_to(edit_admin_user_path(user_subject.id))
      end
    end
    it "renders" do
      get "#{base_url}/#{user_subject.id}/edit"
      expect(response).to render_template :edit
    end
  end

  describe "update" do
    context "non developer" do
      let(:user_subject) { FactoryBot.create(:user, confirmed: false) }
      it "updates all the things that can be edited (finding via user id)" do
        put "#{base_url}/#{user_subject.id}", params: {
          user: {
            name: "New Name",
            email: "newemailexample.com",
            confirmed: true,
            superuser: true,
            developer: true,
            can_send_many_stolen_notifications: true,
            banned: true,
            phone: "9876543210"
          }
        }
        expect(user_subject.reload.name).to eq("New Name")
        expect(user_subject.email).to eq("newemailexample.com")
        expect(user_subject.confirmed).to be_truthy
        expect(user_subject.superuser).to be_truthy
        expect(user_subject.developer).to be_falsey
        expect(user_subject.can_send_many_stolen_notifications).to be_truthy
        expect(user_subject.banned).to be_truthy
        expect(user_subject.phone).to eq "9876543210"
      end
    end
    context "developer" do
      let(:current_user) { FactoryBot.create(:admin_developer) }
      it "updates developer" do
        put "#{base_url}/#{user_subject.id}", params: {
          user: {
            developer: true,
            email: user_subject.email,
            superuser: false,
            can_send_many_stolen_notifications: true,
            banned: true
          }
        }
        user_subject.reload
        expect(user_subject.developer).to be_truthy
      end
    end
  end
end
