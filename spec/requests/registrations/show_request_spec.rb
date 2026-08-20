require "rails_helper"

RSpec.describe "RegistrationsController#show", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/registrations" }
  # show reads from the replica, and the render reaches both of these first_or_create
  # singletons — outside of test they're already-existing rows, so they only select
  before do
    RearGearType.fixed
    Country.united_states
  end

  context "consumer view" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_primary_activity) }
    let(:current_user) { bike.reload.user }

    it "renders the redesigned consumer view with owner actions" do
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq(200)
      # Renders full-width, not wrapped in the content skeleton's sidebar
      expect(response.body).to_not include("primary-content-menu")
      body = whitespace_normalized_body_text
      expect(body).to match("Your bike")
      expect(body).to match("Activity")
      expect(body).to match("Mark stolen")
      expect(body).to match("Add photo")
      expect(body).to match("Edit this bike")
      expect(response.body).to match(edit_bike_path(bike, edit_template: bike.default_edit_template))
    end

    context "current_user not owner" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      it "shows the public view and hides owner actions" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Activity")
        expect(body).to match("Public view")
        expect(body).to match("Share")
        expect(body).to_not match("Sell on Marketplace")
        expect(body).to_not match("Mark stolen")
        expect(body).to_not match("Add photo")
      end
    end

    context "current_user has a general alert" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let!(:b_param) { FactoryBot.create(:b_param_unfinished_registration, creator: current_user) }

      def main_class
        Nokogiri::HTML(response.body).at_css("main#main-content")[:class]
      end

      # The page pulls up by --nav-gap to sit flush under the navbar, so the alert
      # standing in that gap has to zero it or the photos render underneath
      it "zeroes the pull up, and restores it once the alert is gone" do
        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to match("isn't registered yet!")
        expect(main_class).to eq "tw:[--nav-gap:0px]"

        b_param.destroy
        get "#{base_url}/#{bike.id}"
        expect(main_class).to be_blank
      end
    end

    context "current_user is a superuser" do
      let(:current_user) { FactoryBot.create(:superuser) }
      it "offers a View in Super Admin link to the admin bike page" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("View in Super Admin")
        expect(response.body).to match(admin_bike_path(bike.id))
      end
    end

    context "current_user previously owned the bike (sent away)" do
      let(:previous_owner) { bike.reload.user }
      let(:current_user) { previous_owner }
      # Capture the original owner, then transfer to a new owner (demoting the
      # original's ownership to non-current)
      before do
        previous_owner
        FactoryBot.create(:ownership, bike:, user: FactoryBot.create(:user_confirmed))
      end
      it "shows the sent-away badge and hides owner actions" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("No longer your bike")
        expect(body).to_not match("Your bike")
        expect(body).to_not match("Mark stolen")
      end
    end

    context "current_user sent the bike to a new owner who hasn't claimed it" do
      # An unclaimed ownership still resolves bike.owner to the creator
      let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
      let(:current_user) { bike.reload.current_ownership.creator }
      it "shows the sent-to-new-owner notice" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Your bike")
        expect(body).to match("You sent this bike to new-owner@example.com")
        expect(body).to match("been claimed yet")
      end
    end

    context "with photos" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike, image: File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
      let!(:public_image2) { FactoryBot.create(:public_image, imageable: bike, image: File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
      it "renders the add-photo link but no replace/remove links" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Add photo")
        expect(body).to_not match("Replace")
        expect(body).to_not match("Remove")
        expect(response.body).to match(edit_bike_path(bike, edit_template: "photos"))
      end
    end

    context "stolen bike" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record, bike:, phone: "3025551234", phone_for_everyone: true) }
      it "renders the redesign theft details, hiding mark-stolen and marketplace for the owner" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("Activity")
        expect(body).to match("Share my page")
        expect(body).to_not match("Mark stolen")
        expect(body).to_not match("Sell on Marketplace")
        # Theft details always show a location row, even with no location on file
        expect(body).to match("No location given")
        # Owner phone shows when phone visibility permits
        expect(body).to match("302-555-1234")
      end
    end

    context "arrived by scanning a sticker" do
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike:, user: current_user) }
      it "renders the scanned sticker with the re-link form, only with scanned_id" do
        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to_not match("You scanned")

        get "#{base_url}/#{bike.id}", params: {scanned_id: bike_sticker.code}
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("You scanned")
        expect(body).to match(bike_sticker.pretty_code)
        expect(body).to match("Change the bike it links to")
        expect(response.body).to match(bike_sticker_path(id: bike_sticker.code))
      end
    end
  end

  context "short_id" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, id: 35) }
    let(:current_user) { bike.reload.user }

    it "finds the bike from any short_id form and the /r/ short URL" do
      expect(bike.short_id).to eq "r/35"
      ["#{base_url}/35", "#{base_url}/z", "#{base_url}/r/z", "#{base_url}/R.Z-", "/r/z", "/R/Z"].each do |path|
        get path
        expect(response.status).to eq(200)
        expect(whitespace_normalized_body_text).to match("Your bike")
      end
    end

    context "short_id body starting with the prefix letter" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, id: 34992) }

      it "does not double-strip the prefix" do
        expect(bike.short_id).to eq "r/R00"
        get "/#{bike.short_id}"
        expect(response.status).to eq(200)
        expect(whitespace_normalized_body_text).to match("Your bike")
      end
    end
  end

  context "likely_spam bike" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:current_user) { bike.reload.user }
    # likely_spam is excluded by Bike's default_scope, so show has to find it unscoped
    before { bike.update(likely_spam: true) }

    it "renders" do
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq(200)
      expect(whitespace_normalized_body_text).to match("Your bike")
    end
  end

  context "user hidden bike" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:owner) { bike.reload.user }
    let(:current_user) { owner }
    before { bike.update(marked_user_hidden: "true") }

    it "renders for the owner, without the registered badge" do
      expect(bike.reload.user_hidden).to be_truthy
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("Your bike")
      expect(body).to_not match("Registered & protected")
    end

    context "superuser viewing" do
      let(:current_user) { FactoryBot.create(:superuser) }
      it "renders" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        expect(whitespace_normalized_body_text).to match("View in Super Admin")
      end
    end

    context "non-owner viewing" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      it "404s" do
        expect(bike.reload.visible_by?(current_user)).to be_falsey
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq 404
      end
    end

    context "logged out" do
      let(:current_user) { nil }
      it "404s" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq 404
      end
    end
  end

  # An organization's impound record can't be claimed, so consumer claims are for
  # found bikes - impound records without an organization
  context "found bike, viewed by a non-owner" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let!(:impound_record) { FactoryBot.create(:impound_record, bike:) }
    let(:stolen_bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }
    let(:current_user) { stolen_bike.reload.user }

    it "offers to open a claim with one of their stolen bikes" do
      expect(bike.reload.current_impound_record).to be_present
      expect(bike.owner).to_not eq current_user
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("Does this look like your bike?")
      expect(body).to match("Claim found bike")
      expect(response.body).to include(impound_claims_path)
    end

    context "current_user has an impound_claim" do
      let!(:impound_claim) { FactoryBot.create(:impound_claim, user: current_user, impound_record:) }

      it "shows their claim rather than the open-claim prompt" do
        expect(BikeServices::Displayer.display_impound_claim?(bike.reload, current_user)).to be_truthy
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Your claim")
        expect(body).to_not match("Does this look like your bike?")
        expect(response.body).to include(impound_claim_path(impound_claim))
      end
    end

    context "the owner viewing" do
      let(:current_user) { bike.reload.user }
      it "doesn't offer a claim" do
        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to_not match("Does this look like your bike?")
      end
    end
  end

  context "anonymous viewer of an ownerless bike" do
    # A bike with no ownership has owner == nil; a logged-out viewer (current_user
    # nil) must not match the owner view via nil == nil
    let(:bike) { FactoryBot.create(:bike) }
    let(:current_user) { nil }

    it "renders the public view, not the owner view" do
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("Public view")
      expect(body).to_not match("Your bike")
      expect(body).to_not match("Mark stolen")
      expect(body).to_not match("Sell on Marketplace")
      expect(body).to_not match("Add photo")
    end
  end

  context "admin panel" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }

    context "org staff (admin)" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "renders the admin redesign, without feature-gated sections" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Staff")
        expect(body).to match("Bike details")
        expect(body).to match("Owner & access")
        expect(body).to match(bike.owner_name)
        expect(body).to match(bike.owner_email)
        expect(body).to match("E-Vehicle Audit")
        # Gated by credibility_badges and additional_registrations_information
        expect(body).to_not match("Credibility")
        expect(body).to_not match("Other registrations")
      end

      context "bike not registered with the org" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
        it "hides the owner rows and shows the not-registered card" do
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match("Not registered with #{organization.short_name}")
          expect(body).to_not match(bike.owner_name)
          expect(body).to_not match(bike.owner_email)
          # Registration information rows (other than sticker & credibility) are
          # only shown for bikes registered with the org
          expect(body).to_not match("E-Vehicle Audit")
          # With no visible rows, the card shows the muted empty-state note
          expect(body).to match("No registration information visible to #{organization.short_name}")
        end

        context "with a registration-info feature enabled" do
          let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["credibility_badges"]) }
          it "shows the card rather than the empty-state note" do
            get "#{base_url}/#{bike.id}"
            body = whitespace_normalized_body_text
            expect(body).to match("Credibility")
            expect(body).to_not match("No registration information")
          end
        end
      end

      context "with credibility_badges" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["credibility_badges"]) }
        it "shows the credibility score" do
          get "#{base_url}/#{bike.id}"
          expect(whitespace_normalized_body_text).to match("Credibility #{bike.credibility_scorer.score}")
        end
      end

      context "impounded bike" do
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization).reload }
        before { FactoryBot.create(:impound_record, bike:, organization:, user: current_user) }
        it "shows the impounded status, not not-stolen" do
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match("Impounded")
          expect(body).to_not match("Not stolen")
        end
      end

      # The claim card rides in the alerts, which the staff panel renders too - staff
      # aren't being asked whether the bike is theirs
      context "found bike a consumer could claim" do
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization).reload }
        let!(:impound_record) { FactoryBot.create(:impound_record, bike:) }
        it "hides the claim card, even though the viewer could claim it" do
          expect(BikeServices::Displayer.display_impound_claim?(bike.reload, current_user)).to be_truthy
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match("Staff")
          expect(body).to_not match("Does this look like your bike?")
        end
      end

      context "with parking notifications enabled" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["parking_notifications"]) }

        it "shows the create parking notification button" do
          get "#{base_url}/#{bike.id}"
          expect(whitespace_normalized_body_text).to match("New Parking Notification")
        end

        it "shows the View notifications panel even with no notifications" do
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match("No parking notifications")
          # The button subtitle summarizes activity counts
          expect(body).to match("0 Active - 0 Resolved")
        end

        context "with a parking notification" do
          before { FactoryBot.create(:parking_notification, bike:, organization:, user: current_user) }

          it "shows the View notifications panel with the current notification" do
            get "#{base_url}/#{bike.id}"
            body = whitespace_normalized_body_text
            # The View notifications action opens the parking-notification show panel
            expect(body).to match("View notification")
            expect(body).to match("Parked incorrectly")
            expect(response.body).to match(organization_parking_notification_path(ParkingNotification.last.id, organization_id: organization.to_param))
          end
        end

        context "impounded bike" do
          let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization).reload }
          before { FactoryBot.create(:impound_record, bike:, organization:, user: current_user) }

          it "hides the create parking notification button" do
            get "#{base_url}/#{bike.id}"
            body = whitespace_normalized_body_text
            expect(body).to match("Impounded")
            expect(body).to_not match("New Parking Notification")
          end
        end
      end

      context "with impound bikes enabled" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["impound_bikes"]) }

        it "shows the impound action" do
          get "#{base_url}/#{bike.id}"
          expect(response.body).to match('data-panel-name="impound"')
        end

        context "already impounded" do
          let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization).reload }
          before { FactoryBot.create(:impound_record, bike:, organization:, user: current_user) }

          it "shows the Update impound action, its form, and the impound-record card" do
            get "#{base_url}/#{bike.id}"
            body = whitespace_normalized_body_text
            # The Update impound action opens a panel holding the impound-record update form
            expect(body).to match("Update Impound Record")
            expect(response.body).to include("impoundRecordUpdateForm")
            expect(response.body).to_not match('data-panel-name="impound"')
            # The main-column card shows the org impound-record heading + fields
            expect(body).to include("#{organization.short_name} impound record")
            expect(body).to match("Impounded by")
          end
        end
      end

      context "found bike" do
        let(:bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization).reload }
        it "shows the found status, not not-stolen" do
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match("Found")
          expect(body).to_not match("Not stolen")
        end
      end

      context "unregistered bike" do
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, status: "unregistered_parking_notification").reload }
        it "shows the unregistered status and no claim, even though claimed" do
          expect(bike.claimed?).to be_truthy
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match("Unregistered")
          expect(body).to_not match("Not stolen")
          expect(body).to_not match("Claimed")
          # Owner & access shows the parking-notification explanation, no owner rows
          expect(body).to match("not registered to a user. It was added to track parking notifications")
          expect(body).to_not match(bike.owner_email)
        end
      end

      context "with a bike sticker" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["bike_stickers"]) }
        let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, organization:, bike:) }
        it "shows the sticker with its claimed time and an always-present link-sticker action" do
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match(bike_sticker.pretty_code)
          expect(body).to match("claimed")
          expect(body).to match("Link sticker")
          # The link-sticker modal posts to the org sticker update endpoint
          expect(response.body).to include(organization_sticker_path(id: "code", organization_id: organization.to_param))
        end
      end
    end

    context "with organization registration fields" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[reg_address reg_organization_affiliation reg_student_id]) }
      let(:current_user) { FactoryBot.create(:organization_admin, organization: organization) }
      before do
        bike.current_ownership.update(registration_info: {"organization_affiliation" => "student", "student_id" => "sid-99"},
          address_record: FactoryBot.create(:address_record))
      end

      it "shows the org registration fields in owner & access, address beneath phone" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Owner & access")
        expect(body).to match(/Phone.*Address One Shields Ave, Davis, CA 95616/)
        expect(body).to match("Organization affiliation")
        expect(body).to match("Student") # the "student" affiliation, humanized
        expect(body).to match("sid-99")
      end
    end

    context "when the owner has other registrations" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["additional_registrations_information"]) }
      let(:current_user) { FactoryBot.create(:organization_admin, organization:) }
      let(:owner) { FactoryBot.create(:user_confirmed) }
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, user: owner) }
      let!(:other_bikes) { FactoryBot.create_list(:bike_organized, 2, :with_ownership_claimed, creation_organization: organization, user: owner) }

      it "lists the owner's other registrations, excluding this bike" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Other registrations by this user")
        # The owner has 3 registrations; this bike is excluded from the count and table
        expect(body).to match("2 other registrations")
        other_bikes.each { |b| expect(response.body).to include(bike_path(b, organization_id: organization.to_param)) }
        expect(body).to_not match("Showing the")
      end

      context "more than the display limit" do
        before { stub_const("Registrations::Show::WrapperOrgAdmin::Component::OTHER_REGISTRATIONS_LIMIT", 1) }
        it "caps the table and links to the org search for the full list" do
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          expect(body).to match("2 other registrations")
          expect(body).to match("Showing the 1 most recent")
          expect(response.body).to include(organization_registrations_path(organization_id: organization.to_param, search_email: owner.email))
        end
      end

      context "without additional_registrations_information" do
        let(:organization) { FactoryBot.create(:organization) }
        it "hides the other registrations" do
          get "#{base_url}/#{bike.id}"
          expect(whitespace_normalized_body_text).to_not match("Other registrations")
        end
      end
    end

    context "limited role (member_no_bike_edit)" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: organization, role: "member_no_bike_edit") }
      it "hides owner contact and shows the restricted card" do
        get "#{base_url}/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("Limited")
        expect(body).to match("Restricted for your role")
        expect(body).to match("Bike details")
        # Owner name shows for any member of the registering org, email is staff-only
        expect(body).to match(bike.owner_name)
        expect(body).to_not match(bike.owner_email)
      end

      it "resolves a bare ?view_as org slug to the limited view, without an error" do
        get "#{base_url}/#{bike.id}", params: {view_as: organization.to_param}
        body = whitespace_normalized_body_text
        expect(body).to match("Limited")
        expect(body).to_not match("not allowed to view this registration")
      end

      context "with parking notifications and impound enabled" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }

        it "offers create parking notification, not the impound action" do
          get "#{base_url}/#{bike.id}"
          body = whitespace_normalized_body_text
          # Limited members can create a parking notification
          expect(body).to match("New Parking Notification")
          # No impound action for limited (create is staff-only, request impound removed)
          expect(response.body).to_not match('data-panel-name="impound"')
          expect(body).to_not match("Request impound")
        end
      end
    end

    context "removing the organization via organization_id=false" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "drops the admin view on the same request, not only on reload" do
        # With the org in the session (their default), the admin view renders
        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to match("Staff")

        # Removing the org should drop the admin view on this request, not only
        # after a subsequent reload
        get "#{base_url}/#{bike.id}", params: {organization_id: "false"}
        expect(whitespace_normalized_body_text).to_not match("Staff")
      end
    end

    context "view_as switching" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "offers a switcher, applies an allowed view_as, and rejects a disallowed one" do
        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to match("Staff")
        expect(response.body).to include("view_as=public")

        # An allowed view_as applies
        get "#{base_url}/#{bike.id}", params: {view_as: "public"}
        body = whitespace_normalized_body_text
        expect(body).to_not match("Staff")
        expect(body).to match("Public view")

        # A disallowed view_as flashes and falls back to the admin view
        get "#{base_url}/#{bike.id}", params: {view_as: "owner"}
        body = whitespace_normalized_body_text
        expect(body).to match("Staff")
        expect(body).to match("not allowed to view this registration")
      end
    end

    context "view_as another organization" do
      let(:current_user) { FactoryBot.create(:organization_admin, organization:) }
      let(:other_organization) { FactoryBot.create(:organization) }
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization: other_organization, user: current_user) }

      it "sets the passive_organization, so the organization sticks on the next request" do
        # Which organization is default_organization isn't ordered, so put one in the session
        get "#{base_url}/#{bike.id}", params: {organization_id: organization.to_param}
        expect(session[:passive_organization_id]).to eq organization.id

        get "#{base_url}/#{bike.id}", params: {view_as: "#{other_organization.to_param}.staff"}
        expect(whitespace_normalized_body_text).to match("Viewing as #{other_organization.short_name} staff")
        expect(session[:passive_organization_id]).to eq other_organization.id

        get "#{base_url}/#{bike.id}"
        expect(whitespace_normalized_body_text).to match("Viewing as #{other_organization.short_name} staff")
      end
    end

    context "superuser view_as options" do
      let(:current_user) { FactoryBot.create(:superuser) }
      let!(:brakebills) { FactoryBot.create(:organization, name: "Brakebills") }
      let!(:ikes) { FactoryBot.create(:organization, name: "Ikes Bikes") }
      it "offers every view and renders the owner and org-limited perspectives" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("View as owner of bike")
        expect(body).to match("View as #{brakebills.short_name} staff")
        expect(body).to match("View as #{brakebills.short_name} limited")
        # ikes-bikes is the seeded unpaid default alongside the paid brakebills
        expect(body).to match("View as #{ikes.short_name} limited")
        # public is the superuser's default/current view
        expect(body).to match("Viewing as Public")

        # Renders the owner view even though they don't own the bike
        get "#{base_url}/#{bike.id}", params: {view_as: "owner"}
        body = whitespace_normalized_body_text
        expect(body).to match("Your bike")
        expect(body).to match("Mark stolen")

        # Renders an org panel as limited
        get "#{base_url}/#{bike.id}", params: {view_as: "#{brakebills.to_param}.limited"}
        body = whitespace_normalized_body_text
        expect(body).to match("Limited")
        expect(body).to_not match("Staff")
      end

      it "previews an arbitrary organization named in view_as, outside the seeded defaults" do
        other_organization = FactoryBot.create(:organization, name: "Cannondale")
        get "#{base_url}/#{bike.id}", params: {view_as: "#{other_organization.to_param}.staff"}
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("Staff")
        expect(body).to_not match("not allowed to view this registration")
        # The previewed org joins the switcher (staff is current, so limited is the
        # other offered role)
        expect(body).to match("Viewing as #{other_organization.short_name} staff")
        expect(body).to match("View as #{other_organization.short_name} limited")
      end
    end
  end
end
