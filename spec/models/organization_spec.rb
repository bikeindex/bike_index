require "rails_helper"

RSpec.describe Organization, type: :model do
  describe "#nearby_bikes" do
    it "returns bikes within the search radius" do
      FactoryBot.create(:bike, :in_los_angeles)
      nyc_bike_ids = FactoryBot.create_list(:bike, 2, :in_nyc).map(&:id)
      stolen_nyc_bike = FactoryBot.create(:stolen_bike_in_nyc)

      chi_org = FactoryBot.create(:organization_with_regional_bike_counts, :in_chicago)
      nyc_org = FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc)

      expect(chi_org.nearby_bikes.pluck(:id)).to be_empty
      expect(nyc_org.nearby_bikes.pluck(:id)).to match_array([*nyc_bike_ids, stolen_nyc_bike.id])
    end
  end

  describe "bikes in/not nearby organizations, nearby recoveries" do
    it "returns bikes associated with nearby organizations" do
      # an nyc-org bike in chicago
      nyc_org1 = FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc)
      chi_bike1 = FactoryBot.create(:bike_organized, :in_chicago, organization: nyc_org1, skip_geocoding: true, address_set_manually: true)

      # a chicago-org bike in nyc
      chi_org = FactoryBot.create(:organization_with_regional_bike_counts, :in_chicago)
      nyc_bike1 = FactoryBot.create(:bike_organized, :in_nyc, organization: chi_org, skip_geocoding: true, address_set_manually: true)

      nyc_org2 = FactoryBot.create(:organization, :in_nyc)
      nyc_bike2 = FactoryBot.create(:bike_organized, :in_nyc, organization: nyc_org2, skip_geocoding: true, address_set_manually: true)

      nyc_org3 = FactoryBot.create(:organization, :in_nyc)
      nyc_bike3 = FactoryBot.create(:bike_organized, :in_nyc, organization: nyc_org3, skip_geocoding: true, address_set_manually: true)

      nonorg_bikes = FactoryBot.create_list(:bike, 2, :in_nyc)

      chi_bike1.reload
      expect(chi_bike1.to_coordinates).to eq([41.8624488, -87.6591502])

      # stolen record doesn't automatically set latitude on bike,
      # because of testing skip - so use an existing bike with location set
      nonorg_stolen_record = FactoryBot.create(:stolen_record, :in_nyc, bike: nonorg_bikes.last)
      nonorg_stolen_record.add_recovery_information

      expect(nyc_org1.nearby_bikes.pluck(:id))
        .to(match_array([nyc_bike1, nyc_bike2, nyc_bike3, *nonorg_bikes].map(&:id)))

      expect(nyc_org1.nearby_recovered_records.pluck(:id))
        .to(match_array([nonorg_stolen_record.id]))

      # Make sure we're getting the bike from the org
      expect(Bike.organization(nyc_org1).pluck(:id))
        .to(match_array([chi_bike1.id]))

      # Make sure we get the bikes from the org or from nearby
      expect(Bike.organization(nyc_org1.nearby_and_partner_organization_ids))
        .to(match_array([chi_bike1, nyc_bike2, nyc_bike3]))
    end
  end

  describe "nearby_organizations inclusion/exclusion" do
    # LAPD has precincts as child organizations - we need to make the individual organizations have search areas, and have that bubble up
    include_context :geocoder_real
    let(:organization_feature) { FactoryBot.create(:organization_feature, feature_slugs: %w[child_organizations regional_bike_counts]) }
    let(:invoice) { FactoryBot.create(:invoice_paid, organization: organization_parent) }
    let(:country) { Country.united_states }
    let(:state) { FactoryBot.create(:state_california) }
    let(:organization_parent) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius: 50) }
    let(:organization_child1) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius: 3, parent_organization: organization_parent) }
    let(:organization_child2) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius: 3, parent_organization: organization_parent) }
    let(:organization_child3) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius: 3, parent_organization: organization_parent) }
    let(:organization_shop) { FactoryBot.create(:organization, kind: "bike_shop") }
    let(:location_parent) { organization_parent.locations.create(state: state, country: country, city: "Los Angeles", street: "100 West 1st Street", zipcode: "90012", name: organization_parent.name) }
    let(:location_child1) { organization_child1.locations.create(state: state, country: country, city: "Los Angeles", zipcode: "90014", name: organization_child1.name) }
    let(:location_child2) { organization_child2.locations.create(state: state, country: country, city: "Los Angeles", zipcode: "90017", name: organization_child2.name) }
    let(:location_child3) { organization_child3.locations.create(state: state, country: country, city: "Los Angeles", zipcode: "91325", name: organization_child3.name) }
    let(:location_shop) { organization_shop.locations.create(state: state, country: country, city: "Los Angeles", street: "1626 S Hill St", zipcode: "90015", name: organization_shop.name) }
    let(:organization_ids) { [organization_parent.id, organization_child1.id, organization_child2.id, organization_child3.id, organization_shop.id] }
    it "matches organizations as expected" do
      VCR.use_cassette("organizations-nearby_organizations", match_requests_on: [:path]) do
        invoice.update(organization_feature_ids: [organization_feature.id], child_enabled_feature_slugs_string: "regional_bike_counts, child_organizations")
        expect([location_parent, location_child1, location_child2, location_child3, location_shop].size).to eq 5
        UpdateOrganizationAssociationsWorker.new.perform(organization_ids)
        organization_parent.reload && organization_child1.reload && organization_child2.reload && organization_child3.reload && organization_shop.reload

        expect(organization_child1.enabled_feature_slugs).to match_array(%w[child_organizations regional_bike_counts])
        expect(organization_shop.enabled_feature_slugs).to eq([])
        expect(organization_shop.nearby_organizations.pluck(:id)).to eq([])
        expect(organization_parent.nearby_organizations.pluck(:id)).to eq([organization_shop.id])
        # Testing internal method, which is used for calculation
        expect(organization_parent.send(:nearby_organizations_including_siblings).pluck(:id)).to eq([organization_shop.id])
        expect(organization_child1.send(:nearby_organizations_including_siblings).pluck(:id)).to eq([organization_child2.id, organization_shop.id])
        expect(organization_child1.nearby_organizations.pluck(:id)).to eq([organization_shop.id])
        expect(organization_child2.nearby_organizations.pluck(:id)).to eq([organization_shop.id])
        expect(organization_child3.nearby_organizations.pluck(:id)).to eq([])

        expect(organization_parent.nearby_and_partner_organization_ids).to match_array(organization_ids)
        expect(organization_child1.nearby_and_partner_organization_ids).to match_array(organization_ids - [organization_child3.id])
        expect(organization_child2.nearby_and_partner_organization_ids).to match_array(organization_ids - [organization_child3.id])
        expect(organization_child3.nearby_and_partner_organization_ids).to match_array([organization_child3.id, organization_parent.id])
      end
    end
  end

  describe "#set_ambassador_organization_defaults before_save hook" do
    context "when saving a new ambassador org" do
      it "sets non-applicable attributes to sensible ambassador org values" do
        org = FactoryBot.build(
          :organization_ambassador,
          show_on_map: true,
          lock_show_on_map: true,
          api_access_approved: true,
          approved: false,
          website: "http://website.com",
          ascend_name: "ascend-name",
          parent_organization: FactoryBot.create(:organization)
        )

        org.save

        expect(org).to_not be_show_on_map
        expect(org).to_not be_lock_show_on_map
        expect(org).to_not be_api_access_approved
        expect(org).to be_approved
        expect(org.website).to be_blank
        expect(org.ascend_name).to be_blank
        expect(org.parent_organization).to be_blank
      end
    end

    context "when changing an org from a non-ambassador to ambassador kind" do
      it "sets non-applicable attributes to sensible ambassador org values" do
        org = FactoryBot.create(:organization_child, ascend_name: "ascend")
        expect(org).to_not be_show_on_map
        expect(org).to_not be_lock_show_on_map
        expect(org).to_not be_api_access_approved
        expect(org).to be_approved
        expect(org.website).to be_present
        expect(org.ascend_name).to be_present
        expect(org.parent_organization).to be_present

        org.update_attributes(kind: :ambassador)

        expect(org).to_not be_show_on_map
        expect(org).to_not be_lock_show_on_map
        expect(org).to_not be_api_access_approved
        expect(org).to be_approved
        expect(org.website).to be_blank
        expect(org.ascend_name).to be_blank
        expect(org.parent_organization).to be_blank
      end
    end
  end

  describe "admin text search" do
    context "by name" do
      let!(:organization) { FactoryBot.create(:organization, name: "University of Maryland") }
      it "finds the organization" do
        expect(Organization.admin_text_search("maryl")).to eq([organization])
      end
    end
    context "by slug" do
      let!(:organization) { FactoryBot.create(:organization, short_name: "UMD") }
      it "finds the organization" do
        expect(Organization.admin_text_search("umd")).to eq([organization])
      end
    end
    context "through locations" do
      let!(:organization) { location.organization }
      context "by location name" do
        let(:location) { FactoryBot.create(:location, name: "Sweet spot") }
        it "finds the organization" do
          expect(Organization.admin_text_search("sweet Spot")).to eq([organization])
        end
      end
      context "by location city" do
        let(:location) { FactoryBot.create(:location, city: "Chicago") }
        let!(:location_2) { FactoryBot.create(:location, city: "Chicago", organization: organization) }
        it "finds the organization" do
          expect(Organization.admin_text_search("chi")).to eq([organization])
        end
      end
    end
    describe "with_enabled_feature_slugs" do
      let(:organization1) { FactoryBot.create(:organization) }
      let(:organization2) { FactoryBot.create(:organization) }
      before do
        organization1.update_column :enabled_feature_slugs, %w[show_bulk_import reg_phone]
        organization2.update_column :enabled_feature_slugs, %w[show_bulk_import show_recoveries]
      end
      it "finds the organizations" do
        organization1.reload
        organization2.reload
        expect(Organization.with_enabled_feature_slugs(" ")).to be_blank # If we don't have a matching slug, return nil - otherwise it's confusing
        expect(Organization.with_enabled_feature_slugs("show_bulk_import").pluck(:id)).to match_array([organization1.id, organization2.id])
        expect(Organization.with_enabled_feature_slugs(%w[show_bulk_import show_recoveries]).pluck(:id)).to eq([organization2.id])
        expect(Organization.with_enabled_feature_slugs("show_bulk_import reg_phone").pluck(:id)).to eq([organization1.id])
        expect(Organization.admin_text_search(" show_bulk_import").pluck(:id)).to match_array([organization1.id, organization2.id])
        expect(Organization.admin_text_search(" show_bulk_import show_recoveries").pluck(:id)).to eq([organization2.id])
      end
    end
  end

  describe "friendly find" do
    let!(:organization) { FactoryBot.create(:organization, short_name: "something cool") }
    let!(:organization2) { FactoryBot.create(:organization, short_name: "Bike Shop", name: "Trek Store of Santa Cruz") }
    let!(:organization3) { FactoryBot.create(:organization, short_name: "BikeEastBay", previous_slug: "ebbc") }
    it "finds by slug, previous_slug and name" do
      expect(organization2.slug).to eq "bike-shop"
      expect(Organization.friendly_find(" ")).to be_nil
      expect(Organization.friendly_find("something-cool")).to eq organization
      expect(Organization.friendly_find("bike shop")).to eq organization2
      expect(Organization.friendly_find("trek store of SANTA CRUZ")).to eq organization2
      expect(Organization.friendly_find("bikeeastbay")).to eq organization3
      expect(Organization.friendly_find(organization)).to eq organization
    end
  end

  describe "#nearby_organizations" do
    context "given an org without the regional_bike_counts feature" do
      it "returns an empty collection" do
        org = FactoryBot.create(:organization)
        expect(org.nearby_organizations).to be_empty
      end
    end

    context "given no other organizations in the search radius" do
      it "returns an empty collection" do
        org = FactoryBot.create(:organization_with_regional_bike_counts)
        expect(org.nearby_organizations).to be_empty
      end
    end

    context "given other organizations in the search radius" do
      it "returns the corresponding regional sub-orgs" do
        nyc_org1 = FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc)
        nyc_org2 = FactoryBot.create(:organization, :in_nyc)
        nyc_org3 = FactoryBot.create(:organization, :in_nyc)
        FactoryBot.create(:organization, :in_chicago)

        nyc_org1.reload
        expect(nyc_org1.nearby_organizations).to match_array([nyc_org2, nyc_org3])
      end
    end
  end

  describe "map_coordinates" do
    # There is definitely a better way to do this!
    # But for now, just stubbing it because whatever, they haven't put anything in
    it "defaults to SF" do
      expect(Organization.new.map_focus_coordinates).to eq(latitude: 37.7870322, longitude: -122.4061122)
    end
    context "organization with a location" do
      let(:organization) { FactoryBot.create(:organization, approved: true, show_on_map: true) }
      let!(:location) { FactoryBot.create(:location, organization: organization) }
      let!(:location2) { FactoryBot.create(:location, organization: organization, latitude: 12, longitude: -111, skip_geocoding: true) }
      it "is the locations coordinates for the first publicly_visible location, falls back to the first location if neither publicly_visible" do
        expect(organization.default_location).to eq location
        expect(organization.map_focus_coordinates).to eq(latitude: 41.9282162, longitude: -87.6327552)
        location.update_attributes(publicly_visible: false, skip_update: false)
        organization.reload
        expect(organization.default_location.id).to eq location2.id
        expect(organization.map_focus_coordinates).to eq(latitude: 12, longitude: -111)
        location2.update_attributes(not_publicly_visible: true, skip_geocoding: true, skip_update: false)
        organization.reload
        # Now get the first location
        expect(organization.default_location).to eq location
        expect(organization.map_focus_coordinates).to eq(latitude: 41.9282162, longitude: -87.6327552)
      end
    end
  end

  describe "#enabled?" do
    context "given an ambassador organization and 'unstolen_notifications'" do
      it "returns true" do
        ambassador_org = FactoryBot.create(:organization_ambassador)

        enabled = ambassador_org.enabled?("unstolen_notifications")
        expect(enabled).to eq(true)

        enabled = ambassador_org.enabled?(["unstolen_notifications"])
        expect(enabled).to eq(true)

        enabled = ambassador_org.enabled?("unstolen notifications")
        expect(enabled).to eq(true)

        enabled = ambassador_org.enabled?("invalid feature name")
        expect(enabled).to eq(false)
      end
    end
  end

  describe "is_paid and enabled? calculations" do
    let(:organization_feature) { FactoryBot.create(:organization_feature, amount_cents: 10_000, name: "CSV Exports", feature_slugs: %w[child_organizations csv_exports]) }
    let(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0) }
    let(:organization) { invoice.organization }
    let(:organization_child) { FactoryBot.create(:organization) }
    it "uses associations to determine is_paid" do
      expect(organization.enabled?("csv_exports")).to be_falsey
      invoice.update_attributes(organization_feature_ids: [organization_feature.id])
      invoice.update_attributes(child_enabled_feature_slugs_string: "csv_exports")
      expect(invoice.feature_slugs).to eq(%w[child_organizations csv_exports])

      expect { organization.save }.to change { UpdateOrganizationAssociationsWorker.jobs.count }.by(1)

      expect(organization.is_paid).to be_truthy
      expect(organization.enabled_feature_slugs).to eq(["child_organizations", "csv_exports"])
      expect(organization.enabled?("csv_exports")).to be_truthy
      expect(organization_child.is_paid).to be_falsey

      organization_child.update_attributes(parent_organization: organization)
      organization.save

      expect(organization.parent?).to be_truthy
      expect(organization_child.is_paid).to be_truthy
      expect(organization_child.current_invoices.first).to be_blank
      expect(organization_child.enabled_feature_slugs).to eq(["csv_exports"])
      expect(organization_child.enabled?("csv_exports")).to be_truthy # It also checks for the full name version
      expect(organization.child_ids).to eq([organization_child.id])
      expect(organization.child_organizations.pluck(:id)).to eq([organization_child.id])
    end
    context "regional_bike_codes" do
      let!(:regional_child) { FactoryBot.create(:organization, :in_nyc) }
      let!(:regional_parent) { FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc, enabled_feature_slugs: %w[regional_bike_counts bike_stickers]) }
      let!(:bike) { FactoryBot.create(:bike_organized, organization: regional_child) }
      it "sets on the regional organization, applies to bikes" do
        regional_child.reload
        regional_parent.update_attributes(updated_at: Time.current)
        expect(regional_parent.enabled_feature_slugs).to eq(%w[regional_bike_counts bike_stickers])
        expect(regional_parent.regional_ids).to eq([regional_child.id])
        expect(Organization.regional.pluck(:id)).to eq([regional_parent.id])
        expect(regional_child.regional_parents.pluck(:id)).to eq([regional_parent.id])
        regional_child.reload
        # It's private, so, gotta send
        expect(regional_child.send(:calculated_enabled_feature_slugs)).to eq(["bike_stickers"])
        regional_child.update(updated_at: Time.current)
        expect(regional_child.enabled_feature_slugs).to eq(["bike_stickers"])
        bike.reload
        expect(bike.organizations).to eq([regional_child])
        expect(bike.sticker_organizations).to eq([regional_child])
      end
    end
  end

  describe "show_bulk_import?" do
    # Note: the show_bulk_import? for ascend shops is tested by the ascend_pos test
    let(:organization) { Organization.new }
    it "is falsey" do
      expect(organization.show_bulk_import?).to be_falsey
    end
    context "paid_for" do
      let(:organization) { Organization.new(enabled_feature_slugs: ["show_bulk_import"]) }
      it "is truthy" do
        expect(organization.show_bulk_import?).to be_truthy
      end
    end
  end

  describe "restrict_invitations?, permitted_domain_passwordless_signin, matching_domain" do
    it "is truthy" do
      expect(Organization.new.restrict_invitations?).to be_truthy
    end
    context "passwordless_users with passwordless_user_domain" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], passwordless_user_domain: "example.gov") }
      it "is falsey" do
        expect(organization.restrict_invitations?).to be_falsey
        expect(Organization.permitted_domain_passwordless_signin.pluck(:id)).to eq([organization.id])
        expect(Organization.passwordless_email_matching("fakeexample.gov")).to be_blank
        expect(Organization.passwordless_email_matching("f@example.gov@party.gov")).to be_blank
        expect(Organization.passwordless_email_matching("f@éxample.gov")).to be_blank # accent
        expect(Organization.passwordless_email_matching("party@@example.gov")).to be_blank
        expect(Organization.passwordless_email_matching("seth@EXample.gov")).to eq organization
        expect(Organization.passwordless_email_matching("seth@EXample.gov ")).to eq organization
      end
    end
  end

  describe "organization bikes and recoveries" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike) { FactoryBot.create(:stolen_bike, creation_organization_id: organization.id) }
    let(:stolen_record) { bike.fetch_current_stolen_record }
    let!(:bike_organization) { FactoryBot.create(:bike_organization, bike: bike, organization: organization) }
    let!(:bike_unorganized) { FactoryBot.create(:stolen_bike) }
    let(:recovery_information) do
      {
        recovered_description: "recovered it on a special corner",
        index_helped_recovery: true,
        can_share_recovery: true
      }
    end
    it "returns recovered bikes" do
      organization.reload
      expect(organization.bikes).to eq([bike])
      expect(organization.bikes.stolen).to eq([bike])
      # Check the inverse lookup
      expect(Bike.organization(organization)).to eq([bike])
      expect(Bike.organization(organization.id)).to eq([bike])
      # Check recovered
      stolen_record.add_recovery_information(recovery_information)
      bike.reload
      expect(bike.stolen_recovery?).to be_truthy
      expect(organization.recovered_records).to eq([stolen_record])
    end
  end

  describe "set_calculated_attributes" do
    it "sets the short_name and the slug on save" do
      organization = Organization.new(name: "something")
      organization.set_calculated_attributes
      expect(organization.short_name).to be_present
      expect(organization.slug).to be_present
      slug = organization.slug
      organization.save
      expect(organization.slug).to eq(slug)
    end

    it "doesn't xss" do
      org = Organization.new(name: "<script>alert(document.cookie)</script>",
                             website: "<script>alert(document.cookie)</script>")
      org.set_calculated_attributes
      expect(org.name).to match(/stop messing about/i)
      expect(org.website).to eq("http://<script>alert(document.cookie)</script>")
      expect(org.short_name).to match(/stop messing about/i)
    end

    it "permits & in names" do
      organization = Organization.new(name: "Bikes & Trikes")
      organization.set_calculated_attributes
      expect(organization.slug).to eq "bikes-amp-trikes"
      expect(organization.name).to eq "Bikes & Trikes"
    end

    it "protects from name collisions, without erroring because of it's own slug" do
      org1 = Organization.create(name: "Bicycle shop")
      org1.reload.save
      expect(org1.reload.slug).to eq("bicycle-shop")
      organization = Organization.new(name: "Bicycle shop")
      organization.set_calculated_attributes
      expect(organization.slug).to eq("bicycle-shop-2")
    end

    context "deleted things" do
      it "protects from naming collisions from deleted things, by renaming deleted things" do
        org1 = FactoryBot.create(:organization, name: "buckshot", short_name: "buckshot")
        org1.reload
        org1.id = org1.id
        expect(org1.short_name).to eq "buckshot"
        org1.delete
        org1.reload
        expect(org1.deleted_at).to be_present
        expect(org1.slug).to eq "buckshot"
        FactoryBot.create(:organization, name: "buckshot", short_name: "buckshot")
        expect(org1.slug).to eq "buckshot"
      end
    end

    describe "set_locations_shown" do
      let(:country) { FactoryBot.create(:country) }
      let(:organization) { FactoryBot.create(:organization, show_on_map: true, approved: true) }
      let(:location) { Location.create(country_id: country.id, city: "Chicago", name: "stuff", organization_id: organization.id, shown: true) }
      context "organization approved" do
        it "sets the locations shown to be org shown on save" do
          expect(organization.allowed_show?).to be_truthy
          organization.set_calculated_attributes
          expect(location.reload.shown).to be_truthy
        end
      end
      context "not approved" do
        it "sets not shown" do
          organization.update_attribute :approved, false
          organization.reload
          expect(organization.allowed_show?).to be_falsey
          organization.set_calculated_attributes
          expect(location.reload.shown).to be_falsey
        end
      end
    end

    describe "set_auto_user" do
      it "sets the embedable user" do
        organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user_confirmed, email: "embed@org.com")
        FactoryBot.create(:membership_claimed, organization: organization, user: user)
        organization.embedable_user_email = "embed@org.com"
        organization.save
        expect(organization.reload.auto_user_id).to eq(user.id)
      end
      it "does not set the embedable user if user is not a member" do
        organization = FactoryBot.create(:organization)
        FactoryBot.create(:user_confirmed, email: "no_embed@org.com")
        organization.embedable_user_email = "no_embed@org.com"
        organization.save
        expect(organization.reload.auto_user_id).to be_nil
      end
      it "Makes a membership if the user is auto user" do
        organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user_confirmed, email: ENV["AUTO_ORG_MEMBER"])
        organization.embedable_user_email = ENV["AUTO_ORG_MEMBER"]
        organization.save
        expect(organization.reload.auto_user_id).to eq(user.id)
      end
      it "sets the embedable user if it isn't set and the org has members" do
        organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user_confirmed)
        FactoryBot.create(:membership_claimed, user: user, organization: organization)
        organization.save
        expect(organization.reload.auto_user_id).not_to be_nil
      end
    end
  end

  describe "ensure_auto_user" do
    let(:organization) { FactoryBot.create(:organization) }
    context "existing members" do
      let(:member) { FactoryBot.create(:organization_member, organization: organization) }
      before do
        expect(member).to be_present
      end
      it "sets the first user" do
        organization.ensure_auto_user
        organization.reload
        expect(organization.auto_user).to eq member
      end
    end
    context "no members" do
      let(:auto_user) { FactoryBot.create(:user_confirmed, email: ENV["AUTO_ORG_MEMBER"]) }
      before do
        expect(organization).to be_present
        expect(auto_user).to be_present
      end
      it "sets the AUTO_ORG_MEMBER" do
        organization.ensure_auto_user
        organization.reload
        expect(organization.auto_user).to eq auto_user
      end
    end
  end

  describe "law_enforcement_missing_verified_features?" do
    let(:law_enforcement_organization) { Organization.new(kind: "law_enforcement") }
    let(:law_enforcement_organization_with_unstolen) { Organization.new(kind: "law_enforcement", enabled_feature_slugs: ["unstolen_notifications"]) }
    let(:bike_shop_organization) { Organization.new(kind: "bike_shop") }
    it "is true for law_enforcement, false for shop, false for law_enforcement with unstolen_notifications" do
      expect(law_enforcement_organization.law_enforcement_missing_verified_features?).to be_truthy
      expect(bike_shop_organization.law_enforcement_missing_verified_features?).to be_falsey
      expect(law_enforcement_organization_with_unstolen.law_enforcement_missing_verified_features?).to be_falsey
    end
  end

  describe "display_avatar?" do
    context "paid" do
      it "displays" do
        organization = Organization.new(is_paid: true)
        allow(organization).to receive(:avatar) { "a pretty picture" }
        expect(organization.display_avatar?).to be_truthy
      end
    end
  end

  describe "mail_snippet_body" do
    let(:organization) { FactoryBot.create(:organization) }
    before do
      expect((organization && mail_snippet).present?).to be_truthy
      expect(organization.mail_snippets).to be_present
    end
    context "not included snippet type" do
      let(:mail_snippet) { FactoryBot.create(:organization_mail_snippet, organization: organization, kind: "custom") }
      it "returns nil for not-allowed snippet type" do
        expect(organization.mail_snippet_body("custom")).to be nil
      end
    end
    context "non-enabled snippet type" do
      let(:mail_snippet) { FactoryBot.create(:organization_mail_snippet, organization: organization, kind: "partial", is_enabled: false) }
      it "returns nil for not-enabled snippet" do
        expect(organization.mail_snippet_body("partial")).to be nil
      end
    end
    context "enabled snippet" do
      let(:mail_snippet) { FactoryBot.create(:organization_mail_snippet, organization: organization, kind: "security") }
      it "returns nil for not-enabled snippet" do
        expect(organization.mail_snippet_body("security")).to eq mail_snippet.body
      end
    end
  end

  describe "bike_shop_display_integration_alert?" do
    let(:organization) { Organization.new(kind: "law_enforcement", pos_kind: "no_pos") }
    it "is falsey for non-shops" do
      expect(organization.bike_shop_display_integration_alert?).to be_falsey
    end
    context "shop" do
      let(:organization) { Organization.new(kind: "bike_shop", pos_kind: pos_kind) }
      let(:pos_kind) { "no_pos" }
      it "is true" do
        expect(organization.bike_shop_display_integration_alert?).to be_truthy
      end
      context "lightspeed_pos" do
        let(:pos_kind) { "lightspeed_pos" }
        it "is false" do
          expect(organization.bike_shop_display_integration_alert?).to be_falsey
        end
      end
      context "ascend_pos" do
        let(:pos_kind) { "ascend_pos" }
        it "is false" do
          expect(organization.bike_shop_display_integration_alert?).to be_falsey
        end
      end
      context "broken_pos" do
        let(:pos_kind) { "broken_lightspeed_pos" }
        it "is true" do
          expect(organization.bike_shop_display_integration_alert?).to be_truthy
        end
      end
      context "does_not_need_pos" do
        let(:pos_kind) { "does_not_need_pos" }
        it "is falsey" do
          expect(organization.bike_shop_display_integration_alert?).to be_falsey
        end
      end
    end
  end

  describe "additional_registration_fields" do
    let(:organization) { Organization.new }
    it "is false" do
      expect(organization.additional_registration_fields.include?("extra_registration_number")).to be_falsey
      expect(organization.additional_registration_fields.include?("reg_address")).to be_falsey
      expect(organization.additional_registration_fields.include?("reg_phone")).to be_falsey
      expect(organization.additional_registration_fields.include?("organization_affiliation")).to be_falsey
      expect(organization.include_field_reg_phone?).to be_falsey
      expect(organization.include_field_reg_address?).to be_falsey
      expect(organization.include_field_extra_registration_number?).to be_falsey
      expect(organization.include_field_organization_affiliation?).to be_falsey
    end
    context "with organization_features" do
      let(:labels) { {reg_phone: "You have to put this in, jerk", extra_registration_number: "XXXZZZZ"}.as_json }
      let(:organization) { Organization.new(enabled_feature_slugs: %w[extra_registration_number reg_address reg_phone organization_affiliation], registration_field_labels: labels) }
      let(:user) { User.new }
      it "is true" do
        expect(organization.additional_registration_fields.include?("extra_registration_number")).to be_truthy
        expect(organization.additional_registration_fields.include?("reg_address")).to be_truthy
        expect(organization.additional_registration_fields.include?("reg_phone")).to be_truthy
        expect(organization.additional_registration_fields.include?("organization_affiliation")).to be_truthy
        expect(organization.include_field_reg_phone?).to be_truthy
        expect(organization.include_field_reg_phone?(user)).to be_truthy
        expect(organization.include_field_reg_address?).to be_truthy
        expect(organization.include_field_reg_address?(user)).to be_truthy
        expect(organization.include_field_extra_registration_number?).to be_truthy
        expect(organization.include_field_organization_affiliation?(user)).to be_truthy
        # And test the lables
        expect(organization.registration_field_label("extra_registration_number")).to eq "XXXZZZZ"
        expect(organization.registration_field_label("reg_address")).to be_nil
        expect(organization.registration_field_label("reg_phone")).to eq labels["reg_phone"]
        expect(organization.registration_field_label("organization_affiliation")).to be_nil
      end
      context "with user with attributes" do
        let(:user) { User.new(phone: "888.888.8888") }
        it "is falsey" do
          expect(user.phone).to be_present
          expect(organization.additional_registration_fields.include?("reg_phone")).to be_truthy
          expect(organization.include_field_reg_phone?(user)).to be_falsey
          expect(organization.include_field_reg_address?(user)).to be_truthy
        end
      end
    end
  end

  describe "invalid names" do
    let(:organization) { FactoryBot.build(:organization, name: "bike") }
    it "blocks naming something invalid" do
      expect(organization.save).to be_falsey
      expect(organization.id).to be_blank
      organization.update(name: "something else", short_name: "something cool")
      expect(organization.valid?).to be_truthy
      expect(organization.id).to be_present
      valid_names = ["something else", "something cool", "something-cool"]
      expect([organization.name, organization.short_name, organization.slug]).to eq valid_names

      expect(organization.update(short_name: "bikes")).to be_falsey
      organization.reload
      expect([organization.name, organization.short_name, organization.slug]).to eq valid_names

      expect(organization.update(name: "bikés")).to be_falsey
      organization.reload
      expect([organization.name, organization.short_name, organization.slug]).to eq valid_names

      expect(organization.update(name: "400")).to be_falsey
      organization.reload
      expect([organization.name, organization.short_name, organization.slug]).to eq valid_names
    end
  end
end
