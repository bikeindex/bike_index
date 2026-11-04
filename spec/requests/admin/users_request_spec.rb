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

    it "searches in the sort direction it's showing" do
      get base_url, params: {sort: "created_at", direction: "asc"}

      expect(Capybara.string(response.body)).to have_field("direction", type: "hidden", with: "asc")
    end

    it "renders with all search options" do
      get "#{base_url}?query=something"
      expect(response).to render_template :index

      get base_url, params: {search_with_organization: true}
      expect(assigns(:collection).pluck(:id)).to include(organization_user.id)

      get base_url, params: {search_ambassadors: true}
      expect(assigns(:collection).pluck(:id)).to eq([ambassador.id])

      get base_url, params: {search_superusers: true}
      expect(assigns(:collection).pluck(:id)).to include(user_subject.id)

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
      # A tab the show action doesn't render would otherwise raise from the tabs component
      get "#{base_url}/#{user_subject.id}?active_tab=party"
      expect(response).to redirect_to(edit_admin_user_path(user_subject.id))
    end

    context "with a record behind every tab" do
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: user_subject) }
      let!(:user_email) { FactoryBot.create(:user_email, user: user_subject) }
      let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user_subject, serial_number: "LIVE-SERIAL") }
      let!(:bike_deleted) { FactoryBot.create(:bike, :with_ownership_claimed, user: user_subject, serial_number: "GONE-SERIAL", deleted_at: Time.current) }
      let!(:feedback) { FactoryBot.create(:feedback, user: user_subject, body: "FEEDBACK-BODY") }
      let!(:user_alert) { FactoryBot.create(:user_alert, user: user_subject) }
      let!(:membership) { FactoryBot.create(:membership, user: user_subject) }
      let!(:payment) { FactoryBot.create(:payment, user: user_subject) }

      it "renders each tab" do
        Pages::Admin::Users::Show::Component::TABS.each do |tab|
          get "#{base_url}/#{user_subject.id}?active_tab=#{tab}"
          expect(response.code).to eq("200"), "#{tab} rendered #{response.code}"
        end
        get "#{base_url}/#{user_subject.id}?active_tab=emails"
        expect(Nokogiri::HTML(response.body).at_css("h2").text.squish).to eq "Emails #{user_subject.user_emails.count}"
        expect(response.body).to include(user_email.email)
        get "#{base_url}/#{user_subject.id}?active_tab=messages"
        sections = Nokogiri::HTML(response.body).css("h2").map { |heading| heading.text.squish }
        expect(sections).to eq(["Marketplace messages 0", "Alerts 1", "Notifications 0", "Feedbacks 1"])
        expect(response.body).to include(admin_feedback_path(feedback))
        get "#{base_url}/#{user_subject.id}?active_tab=payments"
        sections = Nokogiri::HTML(response.body).css("h2").map { |heading| heading.text.squish }
        expect(sections).to eq(["Memberships 1", "Payments 1"])
        expect(response.body).to include(edit_admin_payment_path(payment))
        get "#{base_url}/#{user_subject.id}?active_tab=organization_roles"
        expect(response.body).to include(organization_role.organization.name)
        expect(Nokogiri::HTML(response.body).at_css("h2").text.squish).to eq "Organizations 1 (0 registration organizations)"
        get "#{base_url}/#{user_subject.id}?active_tab=bikes"
        expect(Nokogiri::HTML(response.body).at_css("h2").text.squish).to start_with("Bikes 1 (view in admin/bikes)")
        expect(response.body).to include("LIVE-SERIAL")
        expect(response.body).to_not include("GONE-SERIAL")
        deleted_path = admin_bikes_path(user_id: user_subject.id, search_status_deleted_only: true, search_status_example: true)
        expect(Nokogiri::HTML(response.body).at_css("a[href='#{deleted_path}']")&.text&.squish).to eq "1 deleted bike"
      end
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
      FactoryBot.create(:membership, user: user_subject)
      FactoryBot.create(:organization_role_claimed, user: user_subject)
      user_email = FactoryBot.create(:user_email, user: user_subject)
      get "#{base_url}/#{user_subject.id}/edit"
      expect(response).to render_template :edit
      expect(response.body).to include(user_email.email)
      expect(response.body).to include("&amp; membership")
      expect(response.body).to_not include("deleted_only")
    end

    describe "dark_mode_preview" do
      let(:current_user) { FactoryBot.create(:superuser, dark_mode_preview:) }
      let(:body) { Nokogiri::HTML(response.body).at_css("body") }
      let(:dark_mode_preview) { false }
      it "isn't dark, and only offers the radios on the user's own page" do
        get "#{base_url}/#{user_subject.id}/edit"
        expect(body[:class]).to be_blank
        expect(body.at_css("input[name='user[dark_mode_preview]']")).to be_nil

        get "#{base_url}/#{current_user.id}/edit"
        expect(Nokogiri::HTML(response.body).css("input[type=radio][name='user[dark_mode_preview]']").count).to eq 2

        get "/"
        expect(Nokogiri::HTML(response.body).at_css("body")[:class].to_s.split).to_not include("dark")
      end
      context "true" do
        let(:dark_mode_preview) { true }
        it "is dark on every layout, beside the page's own body class" do
          get "#{base_url}/#{user_subject.id}/edit"
          expect(body[:class]).to eq "dark"

          ["/", "/oauth/applications", "/payments/new"].each do |path|
            get path
            expect(response.status).to eq 200
            expect(Nokogiri::HTML(response.body).at_css("body")[:class].to_s.split).to include("dark")
          end

          get "/for_bike_shops"
          expect(Nokogiri::HTML(response.body).at_css("body")[:class].to_s.split).to match_array(%w[landing-page-body dark])
        end
      end
    end

    # It rendered a link with ?method=delete, so deleting quietly did nothing but show the user again
    it "carries the delete on the element, never as a query param" do
      get "#{base_url}/#{user_subject.id}/edit"
      link = Nokogiri::HTML(response.body).at_css("a[data-turbo-method][href='/admin/users/#{user_subject.id}']")
      expect(link).to be_present
      expect(link["data-turbo-method"]).to eq "delete"
      expect(link["data-turbo"]).to eq "true" # turbo_method alone is inert
      expect(response.body).to_not include("method=delete")
    end
  end

  describe "destroy" do
    it "deletes the user" do
      expect(user_subject).to be_present
      delete "#{base_url}/#{user_subject.id}"
      expect(flash[:notice]).to be_present
      expect(User.unscoped.find(user_subject.id).deleted_at).to be_present
      expect(User.where(id: user_subject.id)).to be_empty
    end
  end

  describe "update" do
    let(:user_subject) { FactoryBot.create(:user, confirmed: false) }
    let(:ban_user_params) do
      {email: user_subject.email, banned: true,
       can_send_many_stolen_notifications: false, can_send_many_marketplace_messages: false}
    end
    context "superuser limited to users" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let!(:superuser_ability) { SuperuserAbility.create(user: current_user, controller_name: "users") }
      it "doesn't grant universal superuser" do
        patch "#{base_url}/#{current_user.id}", params: {user: ban_user_params.merge(name: "New Name", email: current_user.email, banned: false, superuser: true)}
        expect(current_user.reload.name).to eq "New Name"
        expect(current_user.superuser?).to be_falsey
        expect(current_user.superuser_abilities.pluck(:kind)).to eq(["controller"])
      end
      it "doesn't change another superuser" do
        superuser = FactoryBot.create(:superuser)
        patch "#{base_url}/#{superuser.id}", params: {user: ban_user_params.merge(email: "new@example.com", banned: false)}
        expect(response).to redirect_to(edit_admin_user_path(superuser.id))
        expect(superuser.reload.email).to_not eq "new@example.com"
      end
    end
    context "non developer" do
      it "leaves the user unconfirmed when the box is unchecked" do
        patch "#{base_url}/#{user_subject.id}", params: {user: ban_user_params.merge(name: "New Name", banned: "0", confirmed: "0")}
        expect(user_subject.reload.name).to eq "New Name"
        expect(user_subject.confirmed?).to be_falsey
      end

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
            dark_mode_preview: true,
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
        expect(user_subject.superuser?).to be_truthy
        expect(user_subject.developer).to be_falsey
        expect(user_subject.can_send_many_stolen_notifications).to be_truthy
        expect(user_subject.can_send_many_marketplace_messages).to be_truthy
        expect(user_subject.dark_mode_preview).to be_falsey
        expect(user_subject.banned?).to be_truthy
        expect(user_subject.phone).to eq "9876543210"
        user_ban = user_subject.user_ban
        expect(user_ban).to be_valid
        expect(user_ban.creator_id).to eq current_user.id
        expect(user_ban.reason).to eq "known_criminal"
        expect(user_ban.description).to eq "something here"
        # Bump the auth token, because we want to sign out the user
        expect(user_subject.auth_token).to_not eq og_auth_token
        expect(CallbackJobs::AfterUserChangeJob.jobs.count).to be > 0
        CallbackJobs::AfterUserChangeJob.new.perform(user_subject.id)
        expect(bike.reload.likely_spam).to be_truthy
        expect(bike.deleted_at).to be_blank
        expect(user_subject.superuser_abilities.count).to eq 1
        expect(User.admins.pluck(:id)).to include(user_subject.id)
        expect(marketplace_listing.reload.status).to eq "removed"
      end
    end
    context "dark_mode_preview on the user's own page" do
      let(:own_params) { ban_user_params.merge(email: current_user.email, banned: false, superuser: true) }
      it "updates it" do
        patch "#{base_url}/#{current_user.id}", params: {user: own_params.merge(dark_mode_preview: "true")}
        expect(current_user.reload.dark_mode_preview).to be_truthy

        patch "#{base_url}/#{current_user.id}", params: {user: own_params.merge(dark_mode_preview: "false")}
        expect(current_user.reload.dark_mode_preview).to be_falsey
      end
    end
    context "banning, draining jobs" do
      # UserBan.create! marks the user banned; the ban must survive once the enqueued
      # AfterUserChangeJob (which deletes bans for un-banned users) drains
      it "keeps the ban" do
        expect(user_subject.reload.banned?).to be_falsey
        Sidekiq::Job.clear_all
        patch "#{base_url}/#{user_subject.id}", params: {
          user: ban_user_params.merge(user_ban_attributes: {reason: "known_criminal", description: "something here"})
        }
        Sidekiq::Job.drain_all
        expect(user_subject.reload.banned?).to be_truthy
        user_ban = user_subject.user_ban
        expect(user_ban).to be_present
        expect(user_ban.deleted_at).to be_blank
        expect(user_ban.creator_id).to eq current_user.id
        expect(user_ban.reason).to eq "known_criminal"
      end
    end
    context "banning without a reason" do
      it "still bans the user, without a UserBan" do
        expect(user_subject.reload.banned?).to be_falsey
        Sidekiq::Job.clear_all
        patch "#{base_url}/#{user_subject.id}", params: {user: ban_user_params}
        Sidekiq::Job.drain_all
        expect(user_subject.reload.banned?).to be_truthy
        expect(user_subject.user_ban).to be_blank
      end
    end
    context "updating an existing ban" do
      let(:original_creator) { FactoryBot.create(:superuser) }
      let!(:user_ban) { UserBan.create!(user: user_subject, creator: original_creator, reason: :abuse, description: "old") }
      it "updates the existing ban, keeping the original creator" do
        expect(user_subject.reload.banned?).to be_truthy
        Sidekiq::Job.clear_all
        patch "#{base_url}/#{user_subject.id}", params: {
          user: ban_user_params.merge(user_ban_attributes: {reason: "seo_spam", description: "new"})
        }
        Sidekiq::Job.drain_all
        expect(UserBan.where(user_id: user_subject.id).count).to eq 1
        expect(user_ban.reload).to have_attributes(reason: "seo_spam", description: "new", creator_id: original_creator.id)
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
