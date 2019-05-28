require "spec_helper"

describe Organization do
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
    describe "with_paid_feature_slugs" do
      let(:organization1) { FactoryBot.create(:organization) }
      let(:organization2) { FactoryBot.create(:organization) }
      before do
        organization1.update_column :paid_feature_slugs, %w[show_bulk_import reg_phone]
        organization2.update_column :paid_feature_slugs, %w[show_bulk_import show_recoveries]
      end
      it "finds the organizations" do
        organization1.reload
        organization2.reload
        expect(Organization.with_paid_feature_slugs(" ")).to be_nil # If we don't have a matching slug, return nil - otherwise it's confusing
        expect(Organization.with_paid_feature_slugs("show_bulk_import").pluck(:id)).to match_array([organization1.id, organization2.id])
        expect(Organization.with_paid_feature_slugs(%w[show_bulk_import show_recoveries]).pluck(:id)).to eq([organization2.id])
        expect(Organization.with_paid_feature_slugs("show_bulk_import reg_phone").pluck(:id)).to eq([organization1.id])
        expect(Organization.admin_text_search(" show_bulk_import").pluck(:id)).to match_array([organization1.id, organization2.id])
        expect(Organization.admin_text_search(" show_bulk_import show_recoveries").pluck(:id)).to eq([organization2.id])
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
        organization.reload # Somehow doesn't pick this up - TODO: Rails 5 update
        expect(organization.map_focus_coordinates).to eq(latitude: 41.9282162, longitude: -87.6327552)
      end
    end
  end

  describe "is_paid and paid_for? calculations" do
    let(:paid_feature) { FactoryBot.create(:paid_feature, amount_cents: 10_000, name: "CSV Exports", feature_slugs: ["csv_exports"]) }
    let(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0) }
    let(:organization) { invoice.organization }
    let(:organization_child) { FactoryBot.create(:organization) }
    it "uses associations to determine is_paid" do
      expect(organization.paid_for?("csv_exports")).to be_falsey
      invoice.update_attributes(paid_feature_ids: [paid_feature.id])
      expect(invoice.feature_slugs).to eq(["csv_exports"])
      organization.update_attributes(updated_at: Time.now) # TODO: Rails 5 update - after_commit
      expect(organization.is_paid).to be_truthy
      expect(organization.paid_feature_slugs).to eq(["csv_exports"])
      expect(organization.paid_for?("csv_exports")).to be_truthy
      organization_child.update_attributes(updated_at: Time.now) # TODO: Rails 5 update - after_commit
      expect(organization_child.is_paid).to be_falsey
      organization_child.update_attributes(parent_organization: organization)
      organization_child.reload
      expect(organization_child.is_paid).to be_truthy
      expect(organization_child.current_invoices.first).to eq invoice
      expect(organization_child.paid_feature_slugs).to eq(["csv_exports"])
      expect(organization_child.paid_for?("csv_exports")).to be_truthy # It also checks for the full name version
      expect(organization.child_organizations.pluck(:id)).to eq([organization_child.id])
    end
    context "messages" do
      let!(:paid_feature2) { FactoryBot.create(:paid_feature, name: "abandoned message", feature_slugs: %w[messages abandoned_bike_messages unstolen_notifications]) }
      let!(:user) { FactoryBot.create(:organization_member, organization: organization) }
      it "returns empty for non-geolocated_emails" do
        expect(organization.message_kinds).to eq([])
        expect(organization.paid_for?(nil)).to be_falsey
        expect(organization.paid_for?("messages")).to be_falsey
        expect(organization.paid_for?("geolocated_messages")).to be_falsey
        expect(user.send_unstolen_notifications?).to be_falsey
        invoice.update_attributes(paid_feature_ids: [paid_feature.id, paid_feature2.id])
        organization.update_attributes(updated_at: Time.now) # TODO: Rails 5 update - after_commit
        expect(organization.paid_for?("messages")).to be_truthy
        expect(organization.paid_for?("geolocated_messages")).to be_falsey
        expect(organization.paid_for?("abandoned_bike_messages")).to be_truthy
        expect(organization.message_kinds).to eq(["abandoned_bike_messages"])
        expect(organization.paid_for?("unstolen_notifications")).to be_truthy
        expect(organization.paid_for?("weird_type")).to be_falsey
        expect(organization.paid_for?(%w[geolocated abandoned_bike weird_type])).to be_falsey
        expect(Organization.bike_actions.pluck(:id)).to eq([organization.id])
        user.reload
        expect(user.send_unstolen_notifications?).to be_truthy
      end
    end
  end

  describe "show_bulk_import?" do
    let(:organization) { Organization.new }
    it "is falsey" do
      expect(organization.show_bulk_import?).to be_falsey
    end
    context "paid_for" do
      let(:organization) { Organization.new(paid_feature_slugs: ["show_bulk_import"]) }
      it "is truthy" do
        expect(organization.show_bulk_import?).to be_truthy
      end
    end
    context "with ascend name" do
      let(:organization) { Organization.new(ascend_name: "xxxzzaz") }
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
      expect((Bike.organization(organization.name))).to eq([bike])
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
        org1_id = org1.id
        expect(org1.short_name).to eq "buckshot"
        org1.delete
        org1.reload
        expect(org1.deleted_at).to be_present
        expect(org1.slug).to eq "buckshot"
        org2 = FactoryBot.create(:organization, name: "buckshot", short_name: "buckshot")
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
        FactoryBot.create(:membership, organization: organization, user: user)
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
        FactoryBot.create(:membership, user: user, organization: organization)
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
      let!(:bike) { FactoryBot.create(:bike_organization) }
      it "returns pos type" do
        organization.reload
        expect(organization.pos_kind).to eq "not_pos"
        expect(organization.calculated_pos_kind).to eq "lightspeed_pos"
        # And if bike is created before cut-of for pos kind, it returns broken
        bike_pos.update_attribute :created_at, Time.now - 2.weeks
        expect(organization.calculated_pos_kind).to eq "broken_pos"
      end
    end
  end

  describe "additional_registration_fields" do
    let(:organization) { Organization.new }
    it "is false" do
      expect(organization.additional_registration_fields.include?("reg_secondary_serial")).to be_falsey
      expect(organization.additional_registration_fields.include?("reg_address")).to be_falsey
      expect(organization.additional_registration_fields.include?("reg_phone")).to be_falsey
      expect(organization.additional_registration_fields.include?("reg_affiliation")).to be_falsey
      expect(organization.include_field_reg_phone?).to be_falsey
      expect(organization.include_field_reg_address?).to be_falsey
      expect(organization.include_field_reg_secondary_serial?).to be_falsey
      expect(organization.include_field_reg_affiliation?).to be_falsey
    end
    context "with paid_features" do
      let(:labels) { { reg_phone: "You have to put this in, jerk", reg_secondary_serial: "XXXZZZZ" }.as_json }
      let(:organization) { Organization.new(paid_feature_slugs: %w[reg_secondary_serial reg_address reg_phone reg_affiliation], registration_field_labels: labels) }
      let(:user) { User.new }
      it "is true" do
        expect(organization.additional_registration_fields.include?("reg_secondary_serial")).to be_truthy
        expect(organization.additional_registration_fields.include?("reg_address")).to be_truthy
        expect(organization.additional_registration_fields.include?("reg_phone")).to be_truthy
        expect(organization.additional_registration_fields.include?("reg_affiliation")).to be_truthy
        expect(organization.include_field_reg_phone?).to be_truthy
        expect(organization.include_field_reg_phone?(user)).to be_truthy
        expect(organization.include_field_reg_address?).to be_truthy
        expect(organization.include_field_reg_address?(user)).to be_truthy
        expect(organization.include_field_reg_secondary_serial?).to be_truthy
        expect(organization.include_field_reg_affiliation?(user)).to be_truthy
        # And test the lables
        expect(organization.registration_field_label("reg_secondary_serial")).to eq "XXXZZZZ"
        expect(organization.registration_field_label("reg_address")).to be_nil
        expect(organization.registration_field_label("reg_phone")).to eq labels["reg_phone"]
        expect(organization.registration_field_label("reg_affiliation")).to be_nil
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
