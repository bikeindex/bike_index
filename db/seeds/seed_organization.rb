# A sample organization to seed
hogwarts = Organization.find_by_name("Hogwarts") || Organization.create!(name: "Hogwarts")
invoice = Invoice.create(organization: hogwarts, amount_due: 0, start_at: Time.current - 1.hour)
# This list was created with:
#   OrganizationFeature.has_feature_slugs.map { |of| of.slice(:name, :feature_slugs) }
feature_name_and_slugs = [
  {name: "CSV & XLS export", feature_slugs: ["csv_exports"]},
  {name: "Landing Page", feature_slugs: ["show_partial_registrations"]},
  {name: "Passwordless users", feature_slugs: ["passwordless_users"]},
  {name: "Organization Views: Bike recoveries", feature_slugs: ["show_recoveries"]},
  {name: "Organization Views: Partially registered bikes", feature_slugs: ["show_partial_registrations"]},
  {name: "Organization Views: Search bikes", feature_slugs: ["bike_search"]},
  {name: "Child organizations", feature_slugs: ["child_organizations"]},
  {name: "Organization Views: Custom emails", feature_slugs: ["customize_emails"]},
  {name: "Graduated bikes", feature_slugs: ["graduated_notifications"]},
  {name: "Parking Notifications", feature_slugs: ["parking_notifications", "impound_bikes"]},
  {name: "Skip ownership email", feature_slugs: ["skip_ownership_email"]},
  {name: "Registration field: Address", feature_slugs: ["reg_address"]},
  {name: "Organization Dashboard: Regional bike counts", feature_slugs: ["regional_bike_counts"]},
  {name: "Registration field: Additional serial", feature_slugs: ["reg_extra_registration_number"]},
  {name: "Registration field: Affiliation", feature_slugs: ["reg_organization_affiliation"]},
  {name: "Organization Dashboard: Claimed ownerships", feature_slugs: ["claimed_ownerships"]},
  {name: "Organization Views: Bulk Import impounded", feature_slugs: ["show_bulk_import_impound"]},
  {name: "Registration field: Phone number", feature_slugs: ["reg_phone"]},
  {name: "Avery Export", feature_slugs: ["reg_address", "avery_export"]},
  {name: "Bike Stickers", feature_slugs: ["bike_stickers", "bike_stickers_user_editable"]},
  {name: "Bike Stickers: NOT user editable", feature_slugs: ["bike_stickers"]},
  {name: "Impound bikes", feature_slugs: ["impound_bikes"]},
  {name: "No address for associated users", feature_slugs: ["no_address"]},
  {name: "Official manufacturer organization", feature_slugs: ["official_manufacturer"]},
  {name: "Organization Views: Bulk Import - standard", feature_slugs: ["show_bulk_import"]},
  {name: "Organization Views: Bulk Import stolen", feature_slugs: ["show_bulk_import_stolen"]},
  {name: "Law Enforcement functionality", feature_slugs: ["unstolen_notifications", "additional_registrations_information", "hot_sheet", "show_recoveries", "credibility_badges", "organization_stolen_message"]},
  {name: "Registration field: Student ID", feature_slugs: ["reg_student_id"]},
  {name: "Registration field: Student ID - REQUIRED", feature_slugs: ["reg_student_id", "require_reg_student_id"]},
  {name: "E-Vehicle Model Audits", feature_slugs: ["model_audits"]}
]
feature_ids = []

feature_name_and_slugs.each do |attrs|
  org_feature = OrganizationFeature.find_by_name(attrs[:name]) ||
    OrganizationFeature.create(attrs.merge(amount_cents: 500_00))
  feature_ids << org_feature.id
end

# Give Hogwarts all the features
invoice.update(organization_feature_ids: feature_ids)
