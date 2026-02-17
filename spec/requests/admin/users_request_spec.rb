require "rails_helper"

RSpec.describe Admin::UsersController, type: :request do
  base_url = "/admin/users/"
  include_context :request_spec_logged_in_as_superuser
  let(:user_subject) { FactoryBot.create(:user) }

  describe "index" do
    let!(:ambassador) { FactoryBot.create(:ambassador) }
    let!(:organization_user) { FactoryBot.create(:organization_user) }
    let!(:developer) { FactoryBot.create(:developer) }
    let!(:superuser_ability) { SuperuserAbility.create(user: user_subject) }

    it "renders with all search options" do
      get "#{base_url}?query=something"
      expect(response).to render_template :index

      get base_url, params: {search_with_organization: true}
      expect(assigns(:collection).pluck(:id)).to include(organization_user.id)

      get base_url, params: {search_ambassadors: true}
      expect(assigns(:collection).pluck(:id)).to eq([ambassador.id])

      get base_url, params: {search_superusers: true}
      expect(assigns(:collection).pluck(:id)).to eq([user_subject.id])

      get base_url, params: {search_developers: true}
      expect(assigns(:collection).pluck(:id)).to eq([developer.id])

      get base_url, params: {search_unconfirmed: true}
      expect(assigns(:collection).pluck(:id)).to include(user_subject.id)

      get base_url, params: {search_confirmed: true}
      expect(assigns(:collection).pluck(:id)).to include(current_user.id)

      get base_url, params: {search_invalid: "banned_only"}
      expect(response).to render_template :index

      get base_url, params: {search_invalid: "deleted_only"}
      expect(response).to render_template :index

      get base_url, params: {search_invalid: "all"}
      expect(response).to render_template :index

      get base_url, params: {search_phone: "2063339999"}
      expect(response).to render_template :index

      get base_url, params: {search_domain: "example.com"}
      expect(response).to render_template :index

      get base_url, params: {render_chart: true}
      expect(response).to render_template :index
    end
  end

  describe "show" do
    it "links to edit" do
      get "#{base_url}/#{user_subject.username}"
      expect(response).to redirect_to(edit_admin_user_path(user_subject.username))
    end
  end

  describe "edit" do
    context "user doesn't exist" do
      it "404s" do
        get "#{base_url}/STUFFFFFF/edit"
        expect(response.status).to eq 404
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
    let(:user_subject) { FactoryBot.create(:user, confirmed: false) }
    context "non developer" do
      it "updates all the things that can be edited (finding via user id)" do
        user_subject.reload
        og_auth_token = user_subject.auth_token
        expect(user_subject.banned?).to be_falsey
        current_user.reload
        bike = FactoryBot.create(:bike, :with_primary_activity, :with_ownership_claimed, user: user_subject)
        marketplace_listing = FactoryBot.create(:marketplace_listing, :for_sale, item: bike)
        expect(marketplace_listing).to be_valid
        Sidekiq::Job.clear_all
        patch "#{base_url}/#{user_subject.id}", params: {
          user: {
            name: "New Name",
            email: "newemail@example.com",
            confirmed: true,
            superuser: true,
            developer: "1",
            can_send_many_stolen_notifications: true,
            can_send_many_marketplace_messages: true,
            banned: true,
            phone: "9876543210",
            user_ban_attributes: {
              reason: "known_criminal", description: "something here"
            }
          }
        }
        expect(user_subject.reload.name).to eq("New Name")
        expect(user_subject.email).to eq("newemail@example.com")
        expect(user_subject.confirmed).to be_truthy
        expect(user_subject.superuser).to be_truthy
        expect(user_subject.developer).to be_falsey
        expect(user_subject.can_send_many_stolen_notifications).to be_truthy
        expect(user_subject.can_send_many_marketplace_messages).to be_truthy
        expect(user_subject.banned?).to be_truthy
        expect(user_subject.phone).to eq "9876543210"
        user_ban = user_subject.user_ban
        expect(user_ban).to be_valid
        expect(user_ban.creator_id).to eq current_user.id
        expect(user_ban.reason).to eq "known_criminal"
        expect(user_ban.description).to eq "something here"
        # Bump the auth token, because we want to sign out the user
        expect(user_subject.auth_token).to_not eq og_auth_token
        expect(CallbackJob::AfterUserChangeJob.jobs.count).to be > 0
        CallbackJob::AfterUserChangeJob.new.perform(user_subject.id)
        expect(BikeDeleterJob.jobs.count).to be > 0
        BikeDeleterJob.drain
        expect(bike.reload.deleted_at).to be_within(1).of Time.current
        expect(user_subject.superuser_abilities.count).to eq 1
        expect(User.superuser_abilities.pluck(:id)).to eq([user_subject.id])
        expect(marketplace_listing.reload.status).to eq "removed"
      end
    end
    context "developer" do
      let(:current_user) { FactoryBot.create(:superuser_developer) }
      it "updates developer" do
        user_subject.reload
        og_auth_token = user_subject.auth_token
        put "#{base_url}/#{user_subject.id}", params: {
          user: {
            developer: true,
            email: user_subject.email,
            superuser: false,
            can_send_many_stolen_notifications: true,
            can_send_many_marketplace_messages: true,
            banned: false
          }
        }
        user_subject.reload
        expect(user_subject.developer).to be_truthy
        expect(user_subject.banned?).to be_falsey
        # Shouldn't bump the auth token, because we want to sign out the user
        expect(user_subject.auth_token).to eq og_auth_token
      end
    end

    describe "force_merge_email" do
      let!(:user2) { FactoryBot.create(:user, email: "secondary@email.com") }
      let!(:ownership) { FactoryBot.create(:ownership_claimed, owner_email: "secondary@email.com", user: user2) }
      it "merges the users, even though they're unconfirmed" do
        expect(user2.confirmed?).to be_falsey
        expect(user2.user_emails.pluck(:email)).to eq([])
        user2_id = user2.id
        expect(user2.ownerships.count).to eq 1

        expect(user_subject.confirmed?).to be_falsey
        expect(user_subject.user_emails.pluck(:email)).to eq([])
        expect(user_subject.ownerships.count).to eq 0
        ActionMailer::Base.deliveries = []
        put "#{base_url}/#{user_subject.id}", params: {force_merge_email: "SeconDary@email.com "}
        expect(flash[:success]).to be_present
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(User.where(id: user2_id).count).to eq 0

        user_subject.reload
        expect(user_subject.confirmed?).to be_truthy
        expect(user_subject.ownerships.count).to eq 1
        expect(user_subject.user_emails.pluck(:email)).to match_array([user_subject.email, "secondary@email.com"])

        user_email = user_subject.user_emails.where(email: user_subject.email).first
        expect(user_email.confirmed?).to be_truthy
        expect(user_email.primary?).to be_truthy

        user_email_secondary = user_subject.user_emails.where(email: "secondary@email.com").first
        expect(user_email_secondary.old_user_id).to eq user2_id
        expect(user_email_secondary.confirmed?).to be_truthy
        expect(user_email_secondary.primary?).to be_falsey
      end
      context "with unconfirmed secondary email" do
        it "merges the users" do
          user2.confirm(user2.confirmation_token)
          user2.reload
          expect(user2.confirmed?).to be_truthy
          expect(user2.user_emails.pluck(:email)).to eq(["secondary@email.com"])
          user2_id = user2.id
          expect(user2.ownerships.count).to eq 1

          user_subject.update(additional_emails: "secondary@email.com")
          user_subject.reload
          expect(user_subject.confirmed?).to be_falsey
          expect(user_subject.user_emails.pluck(:email)).to eq(["secondary@email.com"])
          user_email_secondary = user_subject.user_emails.first
          expect(user_email_secondary.confirmed?).to be_falsey
          expect(user_subject.ownerships.count).to eq 0
          ActionMailer::Base.deliveries = []
          put "#{base_url}/#{user_subject.id}", params: {force_merge_email: "SeconDary@email.com "}
          expect(flash[:success]).to be_present
          expect(ActionMailer::Base.deliveries.count).to eq 0
          expect(User.where(id: user2_id).count).to eq 0

          user_subject.reload
          expect(user_subject.confirmed?).to be_truthy
          expect(user_subject.ownerships.count).to eq 1
          expect(user_subject.user_emails.pluck(:email)).to match_array([user_subject.email, "secondary@email.com"])

          user_email = user_subject.user_emails.where(email: user_subject.email).first
          expect(user_email.confirmed?).to be_truthy
          expect(user_email.primary?).to be_truthy

          user_email_secondary.reload
          expect(user_email_secondary.old_user_id).to eq user2_id
          expect(user_email_secondary.confirmed?).to be_truthy
          expect(user_email_secondary.primary?).to be_falsey
        end
      end
      context "not a matching email" do
        it "flash errors" do
          put "#{base_url}/#{user_subject.id}", params: {force_merge_email: "2secondary@email.com"}
          expect(flash[:error]).to be_present
        end
      end
    end
  end
end
