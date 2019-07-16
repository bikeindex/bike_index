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

  describe "edit" do
    context "user doesn't exist" do
      it "404s" do
        # I have no idea why this fails. It works really, but not in tests!
        expect do
          get "#{base_url}/STUFFFFFF/edit"
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    it "shows the edit page if the user exists" do
      get "#{base_url}/#{user_subject.username}/edit"
      expect(response).to render_template :edit
    end
  end

  describe "update" do
    context "non developer" do
      let(:user_subject) { FactoryBot.create(:user, confirmed: false) }
      it "updates all the things that can be edited (finding via user id)" do
        put "#{base_url}/#{user_subject.id}", user: {
                                                name: "New Name",
                                                email: "newemailexample.com",
                                                confirmed: true,
                                                superuser: true,
                                                developer: true,
                                                can_send_many_stolen_notifications: true,
                                                banned: true,
                                              }
        expect(user_subject.reload.name).to eq("New Name")
        expect(user_subject.email).to eq("newemailexample.com")
        expect(user_subject.confirmed).to be_truthy
        expect(user_subject.superuser).to be_truthy
        expect(user_subject.developer).to be_falsey
        expect(user_subject.can_send_many_stolen_notifications).to be_truthy
        expect(user_subject.banned).to be_truthy
      end
    end
    context "developer" do
      let(:current_user) { FactoryBot.create(:admin_developer) }
      it "updates developer" do
        put "#{base_url}/#{user_subject.id}", user: {
                                                developer: true,
                                                email: user_subject.email,
                                                superuser: false,
                                                can_send_many_stolen_notifications: true,
                                                banned: true,
                                              }
        user_subject.reload
        expect(user_subject.developer).to be_truthy
      end
    end
  end
end
