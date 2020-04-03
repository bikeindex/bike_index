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
      chi_bike1 = FactoryBot.create(:bike_organized, :in_chicago, organization: nyc_org1)

      # a chicago-org bike in nyc
      chi_org = FactoryBot.create(:organization_with_regional_bike_counts, :in_chicago)
      nyc_bike1 = FactoryBot.create(:bike_organized, :in_nyc, organization: chi_org)

      nyc_org2 = FactoryBot.create(:organization, :in_nyc)
      nyc_bike2 = FactoryBot.create(:bike_organized, :in_nyc, organization: nyc_org2)

      nyc_org3 = FactoryBot.create(:organization, :in_nyc)
      nyc_bike3 = FactoryBot.create(:bike_organized, :in_nyc, organization: nyc_org3)

      nonorg_bikes = FactoryBot.create_list(:bike, 2, :in_nyc)

      # stolen record doesn't automatically set latitude on bike,
      # because of testing skip - so use an existing bike with location set
      nonorg_stolen_record = FactoryBot.create(:stolen_record, :in_nyc, bike: nonorg_bikes.last)
      nonorg_stolen_record.add_recovery_information

      expect(nyc_org1.nearby_bikes.pluck(:id))
        .to(match_array [nyc_bike1, nyc_bike2, nyc_bike3, *nonorg_bikes].map(&:id))

      expect(nyc_org1.nearby_recovered_records.pluck(:id))
        .to(match_array [nonorg_stolen_record.id])

      # Make sure we're getting the bike from the org
      expect(Bike.organization(nyc_org1).pluck(:id))
        .to(match_array [chi_bike1.id])

      # Make sure we get the bikes from the org or from nearby
      expect(Bike.organization(nyc_org1.nearby_and_partner_organization_ids))
        .to(match_array [chi_bike1, nyc_bike2, nyc_bike3])
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
          parent_organization: FactoryBot.create(:organization),
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

  describe "scopes" do
    it "Shown on map is shown on map *and* validated" do
      expect(Organization.shown_on_map.to_sql).to eq(Organization.where(show_on_map: true).where(approved: true).order(:name).to_sql)
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
        expect(Organization.with_enabled_feature_slugs(" ")).to be_nil # If we don't have a matching slug, return nil - otherwise it's confusing
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
      let(:location) { FactoryBot.create(:location) }
      let!(:organization) { location.organization }
      it "is the locations coordinates" do
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
    let(:paid_feature) { FactoryBot.create(:paid_feature, amount_cents: 10_000, name: "CSV Exports", feature_slugs: ["csv_exports"]) }
    let(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0) }
    let(:organization) { invoice.organization }
    let(:organization_child) { FactoryBot.create(:organization) }
    it "uses associations to determine is_paid" do
      expect(organization.enabled?("csv_exports")).to be_falsey
      invoice.update_attributes(paid_feature_ids: [paid_feature.id])
      invoice.update_attributes(child_enabled_feature_slugs_string: "csv_exports")
      expect(invoice.feature_slugs).to eq(["csv_exports"])

      expect { organization.save }.to change { UpdateAssociatedOrganizationsWorker.jobs.count }.by(1)

      expect(organization.is_paid).to be_truthy
      expect(organization.enabled_feature_slugs).to eq(["csv_exports"])
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
    context "messages" do
      let!(:paid_feature2) { FactoryBot.create(:paid_feature, name: "abandoned message", feature_slugs: %w[messages abandoned_bike_messages unstolen_notifications]) }
      let!(:user) { FactoryBot.create(:organization_member, organization: organization) }
      it "returns empty for non-geolocated_emails" do
        expect(organization.message_kinds).to eq([])
        expect(organization.enabled?(nil)).to be_falsey
        expect(organization.enabled?("messages")).to be_falsey
        expect(organization.enabled?("geolocated_messages")).to be_falsey
        expect(user.send_unstolen_notifications?).to be_falsey

        invoice.update_attributes(paid_feature_ids: [paid_feature.id, paid_feature2.id])
        organization.save

        expect(organization.enabled?("messages")).to be_truthy
        expect(organization.enabled?("geolocated_messages")).to be_falsey
        expect(organization.enabled?("abandoned_bike_messages")).to be_truthy
        expect(organization.message_kinds).to eq(["abandoned_bike_messages"])
        expect(organization.message_kinds_except_abandoned).to eq([])
        expect(organization.enabled?("unstolen_notifications")).to be_truthy
        expect(organization.enabled?("weird_type")).to be_falsey
        expect(organization.bike_actions?).to be_truthy
        expect(organization.enabled?(%w[geolocated abandoned_bike weird_type])).to be_falsey
        expect(Organization.bike_actions.pluck(:id)).to eq([organization.id])

        expect(user.reload.send_unstolen_notifications?).to be_truthy
      end
    end
    context "regional_bike_codes" do
      let!(:regional_child) { FactoryBot.create(:organization, :in_nyc) }
      let!(:regional_parent) { FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc, enabled_feature_slugs: %w[regional_bike_counts regional_stickers]) }
      it "sets on the regional organization" do
        regional_child.reload
        regional_parent.update_attributes(updated_at: Time.current)
        expect(regional_parent.enabled_feature_slugs).to eq(%w[regional_bike_counts regional_stickers])
        expect(regional_parent.regional_ids).to eq([regional_child.id])
        expect(Organization.regional.pluck(:id)).to eq([regional_parent.id])
        expect(regional_child.regional_parents.pluck(:id)).to eq([regional_parent.id])
        regional_child.reload
        # It's private, so, gotta send
        expect(regional_child.send(:calculated_enabled_feature_slugs)).to eq(["bike_stickers"])
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

  describe "organization bikes and recoveries" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike) { FactoryBot.create(:stolen_bike, creation_organization_id: organization.id) }
    let(:stolen_record) { bike.find_current_stolen_record }
    let!(:bike_organization) { FactoryBot.create(:bike_organization, bike: bike, organization: organization) }
    let!(:bike_unorganized) { FactoryBot.create(:stolen_bike) }
    let(:recovery_information) do
      {
        recovered_description: "recovered it on a special corner",
        index_helped_recovery: true,
        can_share_recovery: true,
      }
    end
    it "returns recovered bikes" do
      organization.reload
      expect(organization.bikes).to eq([bike])
      expect(organization.bikes.stolen).to eq([bike])
      # Check the inverse lookup
      expect((Bike.organization(organization))).to eq([bike])
      expect((Bike.organization(organization.id))).to eq([bike])
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
          expect(organization.allowed_show).to be_truthy
          organization.set_calculated_attributes
          expect(location.reload.shown).to be_truthy
        end
      end
      context "not approved" do
        it "sets not shown" do
          organization.update_attribute :approved, false
          organization.reload
          expect(organization.allowed_show).to be_falsey
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

  describe "display_avatar" do
    context "unpaid" do
      it "does not display" do
        organization = Organization.new(is_paid: false)
        allow(organization).to receive(:avatar) { "a pretty picture" }
        expect(organization.display_avatar).to be_falsey
      end
    end
    context "paid" do
      it "displays" do
        organization = Organization.new(is_paid: true)
        allow(organization).to receive(:avatar) { "a pretty picture" }
        expect(organization.display_avatar).to be_truthy
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
      let(:mail_snippet) { FactoryBot.create(:organization_mail_snippet, organization: organization, name: "fool") }
      it "returns nil for not-allowed snippet type" do
        expect(organization.mail_snippet_body("fool")).to be nil
      end
    end
    context "non-enabled snippet type" do
      let(:mail_snippet) { FactoryBot.create(:organization_mail_snippet, organization: organization, is_enabled: false) }
      it "returns nil for not-enabled snippet" do
        expect(organization.mail_snippet_body(mail_snippet.name)).to be nil
      end
    end
    context "enabled snippet" do
      let(:mail_snippet) { FactoryBot.create(:organization_mail_snippet, organization: organization, name: "security") }
      it "returns nil for not-enabled snippet" do
        expect(organization.mail_snippet_body(mail_snippet.name)).to eq mail_snippet.body
      end
    end
  end

  describe "calculated_pos_kind" do
    context "organization with pos bike and non pos bike" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user, kind: "bike_shop") }
      let!(:bike_pos) { FactoryBot.create(:bike_lightspeed_pos, organization: organization) }
      let!(:bike) { FactoryBot.create(:bike_organized, organization: organization) }
      it "returns pos type" do
        organization.reload
        expect(organization.pos_kind).to eq "no_pos"
        expect(organization.calculated_pos_kind).to eq "lightspeed_pos"
        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.pos_kind).to eq "lightspeed_pos"
        # And if bike is created before cut-of for pos kind, it returns broken
        bike_pos.update_attribute :created_at, Time.current - 2.weeks
        expect(organization.calculated_pos_kind).to eq "broken_pos"
      end
    end
    context "ascend_name" do
      let(:organization) { FactoryBot.create(:organization, ascend_name: "SOMESHOP") }
      it "returns ascend_pos" do
        expect(organization.calculated_pos_kind).to eq "ascend_pos"
        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind?).to be_blank
        expect(organization.pos_kind).to eq "ascend_pos"
        expect(organization.show_bulk_import?).to be_truthy
      end
    end
    context "manual_pos_kind" do
      let(:organization) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos") }
      it "overrides everything" do
        expect(organization.manual_lightspeed_pos?).to be_truthy
        expect(organization.pos_kind).to eq "no_pos"
        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind).to eq "lightspeed_pos"
        expect(organization.pos_kind).to eq "lightspeed_pos"
        organization.update_attribute :manual_pos_kind, "broken_pos"

        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind).to eq "broken_pos"
        expect(organization.pos_kind).to eq "broken_pos"
      end
    end
    context "recent bikes" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user, kind: "bike_shop") }
      it "no_pos, does_not_need_pos if older organization" do
        organization.reload
        expect(organization.calculated_pos_kind).to eq "no_pos"
        3.times { FactoryBot.create(:bike_organized, organization: organization) }
        organization.reload
        expect(organization.calculated_pos_kind).to eq "no_pos"
        organization.update_attribute :created_at, Time.current - 2.weeks
        organization.reload
        expect(organization.calculated_pos_kind).to eq "does_not_need_pos"
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
        let(:pos_kind) { "broken_pos" }
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
    context "with paid_features" do
      let(:labels) { { reg_phone: "You have to put this in, jerk", extra_registration_number: "XXXZZZZ" }.as_json }
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
end
