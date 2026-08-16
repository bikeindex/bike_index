# Seed organizations: Brakebills, Ike's Bikes, Cannondale, and Bike Recovery Team

# --- Organization Features ---
# This list was created with:
#   OrganizationFeature.has_feature_slugs.map { |of| of.slice(:name, :feature_slugs) }
feature_name_and_slugs = [
  {name: "Ad space", feature_slugs: []},
  {name: "Automatic User Role", description: "Gives every user with a matching email domain this default role", feature_slugs: ["user_role_for_user_email_domain"]},
  {name: "Avery Export", feature_slugs: ["reg_address", "avery_export"]},
  {name: "Bike Stickers", feature_slugs: ["bike_stickers", "bike_stickers_user_editable"]},
  {name: "Bike Stickers: NOT user editable", feature_slugs: ["bike_stickers"]},
  {name: "Bike Stickers: Sticker order", feature_slugs: []},
  {name: "CSV & XLS export", feature_slugs: ["csv_exports"]},
  {name: "Child organizations", feature_slugs: ["child_organizations"]},
  {name: "Co-branded email campaign", feature_slugs: []},
  {name: "Co-branded flyer", feature_slugs: []},
  {name: "E-Vehicle Model Audits", feature_slugs: ["model_audits"]},
  {name: "Graduated bikes", feature_slugs: ["graduated_notifications"]},
  {name: "Impound bikes", feature_slugs: ["impound_bikes"]},
  {name: "Import existing bikes", feature_slugs: []},
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
  {name: "Organization Registration Sequences", feature_slugs: ["registration_sequences", "registration_sequences_edit"]},
  {name: "Organization Registration Sequences: view only", feature_slugs: ["registration_sequences"]},
  {name: "Organization Views: Bike recoveries", feature_slugs: ["show_recoveries"]},
  {name: "Organization Views: Bulk Import - standard", feature_slugs: ["show_bulk_import"]},
  {name: "Organization Views: Bulk Import impounded", feature_slugs: ["show_bulk_import_impound"]},
  {name: "Organization Views: Bulk Import stolen", feature_slugs: ["show_bulk_import_stolen"]},
  {name: "Organization Views: Custom emails", feature_slugs: ["customize_emails"]},
  {name: "Organization Views: Partially registered bikes", feature_slugs: ["show_partial_registrations"]},
  {name: "Organization Views: Search bikes", feature_slugs: ["bike_search"]},
  {name: "Parking Notifications", feature_slugs: ["parking_notifications", "impound_bikes"]},
  {name: "Passwordless users", feature_slugs: ["passwordless_users"]},
  {name: "Product review", feature_slugs: []},
  {name: "Registration field: Address", feature_slugs: ["reg_address"]},
  {name: "Registration field: Address - REQUIRED", feature_slugs: ["reg_address", "require_reg_address"]},
  {name: "Registration field: Additional serial", feature_slugs: ["reg_extra_registration_number"]},
  {name: "Registration field: Affiliation", feature_slugs: ["reg_organization_affiliation"]},
  {name: "Registration field: Phone number", feature_slugs: ["reg_phone"]},
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

brakebills_skipped_feature_names = ["Automatic User Role", "Avery Export", "Passwordless users", "Single Sign On (SSO)", "Skip ownership email"]

feature_name_and_slugs.each do |attrs|
  org_feature = OrganizationFeature.find_by_name(attrs[:name]) ||
    OrganizationFeature.create(attrs.merge(amount_cents: 500_00))

  next if brakebills_skipped_feature_names.include?(attrs[:name])

  if attrs[:name] == "Official manufacturer organization"
    official_manufacturer_feature_id = org_feature.id
  else
    law_enforcement_feature_id = org_feature.id if attrs[:name] == "Law Enforcement functionality"
    brakebills_feature_ids << org_feature.id
  end
end

# --- Brakebills: every feature except brakebills_skipped_feature_names, on an is_endless invoice ---
brakebills = Organization.find_by_name("Brakebills") || Organization.create!(name: "Brakebills")
brakebills_invoice = Invoice.create(organization: brakebills, amount_due: 0, start_at: Time.current - 1.hour, is_endless: true)
brakebills_invoice.update(organization_feature_ids: brakebills_feature_ids)
OrganizationRole.create(organization_id: brakebills.id, user_id: User.find_by_email("member@brakebills.edu").id, role: "member")

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

# --- Ike's Bikes ---
ikes = Organization.find_by_name("Ikes Bike's") || Organization.create(name: "Ikes Bike's", website: "", short_name: "Ikes", show_on_map: true)
ikes.save

# --- Cannondale ---
cannondale = Organization.find_by_name("Cannondale") || Organization.create!(name: "Cannondale", manufacturer_id: Manufacturer.find_by_name("Cannondale")&.id)
cannondale_invoice = Invoice.create(organization: cannondale, amount_due: 0, start_at: Time.current - 1.hour, subscription_end_at: 1.year.from_now)
cannondale_invoice.update(organization_feature_ids: [official_manufacturer_feature_id].compact)

# Create cannondale user and make admin
cannondale_user = User.create(name: "Cannondale Admin", email: "cannondale@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true)
cannondale_user.confirm(cannondale_user.confirmation_token)
cannondale_user.save
OrganizationRole.create(organization_id: cannondale.id, user_id: cannondale_user.id, role: "admin")

# --- Bike Recovery Team: Law Enforcement functionality ---
# phoneable_by?'s police check reads Organization.law_enforcement — the kind, not the feature slugs
recovery_team = Organization.find_by_name("Bike Recovery Team") || Organization.create!(name: "Bike Recovery Team")
recovery_team.update(kind: :law_enforcement)
recovery_team_invoice = Invoice.create(organization: recovery_team, amount_due: 0, start_at: Time.current - 1.hour, subscription_end_at: 1.year.from_now)
recovery_team_invoice.update(organization_feature_ids: [law_enforcement_feature_id].compact)

recovery_team_user = User.find_by_email("recovery@bikeindex.org") ||
  User.create(name: "Recovery Team Member", email: "recovery@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true)
recovery_team_user.confirm(recovery_team_user.confirmation_token) unless recovery_team_user.confirmed?
OrganizationRole.create(organization_id: recovery_team.id, user_id: recovery_team_user.id, role: "member")

# Make sure example organization exists
Organization.example

puts "Organizations seeded: Brakebills, Ikes Bike's, Cannondale, Bike Recovery Team\n"
