# Seed organizations: Brakebills, Craig's Bike Shop, Cannondale, Bike Recovery Team and City of Palo Alto

# --- Organization Features ---
# This list was created with:
#   OrganizationFeature.order(:name).map { |of| of.slice(:name, :feature_slugs) }
feature_name_and_slugs = [
  {name: "Ad space", feature_slugs: []},
  {name: "Avery Export", feature_slugs: ["avery_export", "reg_address", "require_reg_address"]},
  {name: "Bike Stickers", feature_slugs: ["bike_stickers", "bike_stickers_user_editable"]},
  {name: "Bike Stickers: NOT user editable", feature_slugs: ["bike_stickers"]},
  {name: "Bike Stickers: Sticker order", feature_slugs: []},
  {name: "CSV & XLS export", feature_slugs: ["csv_exports"]},
  {name: "Child organizations", feature_slugs: ["child_organizations"]},
  {name: "Co-branded email campaign", feature_slugs: []},
  {name: "Co-branded flyer", feature_slugs: []},
  {name: "E-Vehicle Model Audits", feature_slugs: ["model_audits"]},
  {name: "Graduated bikes", feature_slugs: ["graduated_notifications"]},
  {name: "Import existing bikes", feature_slugs: []},
  {name: "Impound bikes", feature_slugs: ["impound_bikes"]},
  {name: "Landing Page", feature_slugs: ["show_partial_registrations"]},
  {name: "Landing Page: Add Custom field(s)", feature_slugs: []},
  {name: "Law Enforcement functionality", feature_slugs: ["unstolen_notifications", "additional_registrations_information", "hot_sheet", "show_recoveries", "credibility_badges", "organization_stolen_message"]},
  {name: "No address for associated users", feature_slugs: ["no_address"]},
  {name: "Official manufacturer organization", feature_slugs: ["official_manufacturer"]},
  {name: "One-time export email", feature_slugs: []},
  {name: "Ongoing programming costs for standard system", feature_slugs: []},
  {name: "Organization Dashboard: Claimed ownerships", feature_slugs: ["claimed_ownerships"]},
  {name: "Organization Dashboard: Regional bike counts", feature_slugs: ["regional_bike_counts"]},
  {name: "Organization Registration Notes", feature_slugs: ["registration_notes"]},
  {name: "Organization Views: Bike recoveries", feature_slugs: ["show_recoveries"]},
  {name: "Organization Views: Bulk Import - standard", feature_slugs: ["show_bulk_import"]},
  {name: "Organization Views: Bulk Import impounded", feature_slugs: ["show_bulk_import_impound"]},
  {name: "Organization Views: Bulk Import stolen", feature_slugs: ["show_bulk_import_stolen"]},
  {name: "Organization Views: Custom emails", feature_slugs: ["customize_emails"]},
  {name: "Organization Views: Partially registered bikes", feature_slugs: ["show_partial_registrations"]},
  {name: "Organization Views: Search bikes", feature_slugs: ["bike_search"]},
  {name: "Parking Notifications", feature_slugs: ["parking_notifications", "impound_bikes"]},
  {name: "Passwordless users", feature_slugs: ["passwordless_users", "user_role_for_user_email_domain"]},
  {name: "Product review", feature_slugs: []},
  {name: "Registration Sequences: Edit", feature_slugs: ["registration_sequences", "registration_sequences_edit"]},
  {name: "Registration Sequences: View only", feature_slugs: ["registration_sequences"]},
  {name: "Registration field: Additional serial", feature_slugs: ["reg_extra_registration_number"]},
  {name: "Registration field: Address", feature_slugs: ["reg_address"]},
  {name: "Registration field: Address - REQUIRED", feature_slugs: ["reg_address", "require_reg_address"]},
  {name: "Registration field: Affiliation", feature_slugs: ["reg_organization_affiliation"]},
  {name: "Registration field: Phone number", feature_slugs: ["reg_phone"]},
  {name: "Registration field: Phone number - REQUIRED", feature_slugs: ["reg_phone", "require_reg_phone"]},
  {name: "Registration field: Student ID", feature_slugs: ["reg_student_id"]},
  {name: "Registration field: Student ID - REQUIRED", feature_slugs: ["reg_student_id", "require_reg_student_id"]},
  {name: "Registration field: True/False question", feature_slugs: []},
  {name: "Single Sign On (SSO)", feature_slugs: ["saml_sso"]},
  {name: "Skip ownership email", feature_slugs: ["skip_ownership_email"]},
  {name: "Social media ad campaign", feature_slugs: []}
]

brakebills_feature_ids = []
official_manufacturer_feature_id = nil
law_enforcement_feature_id = nil
bike_search_feature_id = nil

brakebills_skipped_feature_names = ["Avery Export", "Passwordless users", "Single Sign On (SSO)", "Skip ownership email"]

feature_name_and_slugs.each do |attrs|
  org_feature = OrganizationFeature.find_by_name(attrs[:name]) ||
    OrganizationFeature.create(attrs.merge(amount_cents: 500_00))

  next if brakebills_skipped_feature_names.include?(attrs[:name])

  if attrs[:name] == "Official manufacturer organization"
    official_manufacturer_feature_id = org_feature.id
  else
    law_enforcement_feature_id = org_feature.id if attrs[:name] == "Law Enforcement functionality"
    bike_search_feature_id = org_feature.id if attrs[:name] == "Organization Views: Search bikes"
    brakebills_feature_ids << org_feature.id
  end
end

# An invoice's features only reach enabled_feature_slugs when the organization is saved again.
# Invoice#update_organization enqueues that, and seeds run without a worker.
def seed_invoice(organization:, feature_ids:, **invoice_attrs)
  invoice = Invoice.create(organization:, amount_due: 0, start_at: Time.current - 1.hour, **invoice_attrs)
  invoice.update(organization_feature_ids: feature_ids.compact)
  UpdateOrganizationAssociationsJob.new.perform(organization.id)
end

def seed_organization_member(organization:, email:, name: nil, role: "member")
  user = User.find_by_email(email) ||
    User.create!(name:, email:, password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true)
  user.confirm(user.confirmation_token) unless user.confirmed?
  OrganizationRole.find_or_create_by!(organization_id: organization.id, user_id: user.id, role:)
  user
end

# --- Brakebills: every feature except brakebills_skipped_feature_names, on an is_endless invoice ---
SeedHelpers.tick
brakebills = Organization.find_by_name("Brakebills") || Organization.create!(name: "Brakebills")
seed_organization_member(organization: brakebills, email: "member@brakebills.edu")
seed_invoice(organization: brakebills, feature_ids: brakebills_feature_ids, is_endless: true)

# Logo (rasterized from db/seeds/images/brakebills.svg — CarrierWave rejects SVG)
if brakebills.avatar.blank?
  File.open(Rails.root.join("db/seeds/images/brakebills.png")) { |file| brakebills.avatar = file }
  brakebills.save!
end

brakebills.update!(registration_field_labels: {owner_email: "Brakebills email"})

landing_page_template = File.read(Rails.root.join("db/seeds/organization_landing_page.html.erb"))
OrganizationLandingPage.find_or_initialize_by(organization_id: brakebills.id).tap do |landing_page|
  landing_page.update!(body: ERB.new(landing_page_template).result_with_hash(organization: brakebills),
    enabled: landing_page.env_enabled?)
end

# --- Craig's Bike Shop ---
SeedHelpers.tick
craigs = Organization.find_by_name("Craig's Bike Shop") ||
  Organization.create!(name: "Craig's Bike Shop", website: "", short_name: "Craig's", show_on_map: true, kind: :bike_shop)
seed_organization_member(organization: craigs, name: "Craig Shop Mechanic", email: "craigs@bikeindex.org")

# --- Cannondale ---
SeedHelpers.tick
cannondale = Organization.find_by_name("Cannondale") ||
  Organization.create!(name: "Cannondale", kind: :bike_manufacturer, manufacturer_id: Manufacturer.find_by_name("Cannondale")&.id)
seed_organization_member(organization: cannondale, name: "Cannondale Admin", email: "cannondale@bikeindex.org", role: "admin")
seed_invoice(organization: cannondale, feature_ids: [official_manufacturer_feature_id], subscription_end_at: 1.year.from_now)

# --- Bike Recovery Team: Law Enforcement functionality ---
# phoneable_by?'s police check reads Organization.law_enforcement — the kind, not the feature slugs
SeedHelpers.tick
recovery_team = Organization.find_by_name("Bike Recovery Team") ||
  Organization.create!(name: "Bike Recovery Team", kind: :law_enforcement)
seed_organization_member(organization: recovery_team, name: "Recovery Team Member", email: "recovery@bikeindex.org")
seed_invoice(organization: recovery_team, feature_ids: [law_enforcement_feature_id], subscription_end_at: 1.year.from_now)

# --- City of Palo Alto: municipality with bike search ---
SeedHelpers.tick
palo_alto = Organization.find_by_name("City of Palo Alto") ||
  Organization.create!(name: "City of Palo Alto", short_name: "Palo Alto", kind: :municipality)
seed_organization_member(organization: palo_alto, name: "Palo Alto Staffer", email: "paloalto@bikeindex.org")
seed_invoice(organization: palo_alto, feature_ids: [bike_search_feature_id], subscription_end_at: 1.year.from_now)

seed_organization_member(organization: Organization.example, email: "example_user@bikeindex.org")

puts "Organizations seeded: Brakebills, Craig's Bike Shop, Cannondale, Bike Recovery Team, City of Palo Alto\n"
