# Seed records required for the OrganizedMailer previews
# (`/rails/mailers/organized_mailer/<kind>`) to render. Each preview action
# fetches its target via `Model.last`/`Model.scope.last`, so we need at least
# one of each kind tied to Hogwarts.

hogwarts = Organization.find_by_name("Hogwarts")
member = User.find_by_email("member@bikeindex.org")
user = User.find_by_email("user@bikeindex.org")

raise "missing Hogwarts org or test users" if hogwarts.blank? || member.blank? || user.blank?

# --- Mail snippets exercise the `organization_message_snippet` paths ---
{
  "graduated_notification" => "<p>Time to renew your registration with Hogwarts!</p>",
  "impound_claim_approved" => "<p>Your impound claim was approved. Please contact us to retrieve your bike.</p>",
  "impound_claim_denied" => "<p>Your impound claim was denied. Reply to this email if you'd like to appeal.</p>"
}.each do |kind, body|
  snippet = hogwarts.mail_snippets.where(kind:).first_or_initialize
  snippet.update!(body:, is_enabled: true)
end

# --- GraduatedNotification: needs deliver_graduated_notifications? to be true ---
hogwarts.update!(graduated_notification_interval: 1.year.to_i) if hogwarts.graduated_notification_interval.blank?

if GraduatedNotification.where(organization: hogwarts).none?
  graduated_bike = BikeServices::Creator.new.create_bike(
    BParam.create!(creator: user, params: {
      bike: {
        cycle_type: "bike",
        propulsion_type: "foot-pedal",
        serial_number: "GRADUATED01",
        manufacturer_id: Manufacturer.frame_makers.pluck(:id).sample,
        primary_frame_color_id: Color.pluck(:id).sample,
        rear_tire_narrow: "true",
        handlebar_type: HandlebarType.slugs.first,
        owner_email: user.email,
        creation_organization_id: hogwarts.id.to_s
      }
    })
  )
  raise "Graduated bike creation failed" if graduated_bike.errors.any?

  # Backdate so the notification's interval window is satisfied
  old_time = Time.current - 13.months
  graduated_bike.update_columns(created_at: old_time)
  graduated_bike.current_ownership.update_columns(created_at: old_time, claimed: true, user_id: user.id)
  BikeOrganization.where(bike: graduated_bike).update_all(created_at: old_time)

  GraduatedNotification.create!(bike: graduated_bike, organization: hogwarts, user: user)
  puts "  Created GraduatedNotification for bike ##{graduated_bike.id}"
end

# --- HotSheet: preset stolen_record_ids and recipient_ids so we don't depend
# on hot_sheet_configuration's bounding box (the preview just renders) ---
if HotSheet.where(organization: hogwarts).none?
  stolen_record_ids = StolenRecord.current.reorder(date_stolen: :desc).limit(5).pluck(:id)
  HotSheet.create!(
    organization: hogwarts,
    sheet_date: Time.current.to_date,
    recipient_ids: [member.id, hogwarts.auto_user_id].compact,
    stolen_record_ids: stolen_record_ids
  )
  puts "  Created HotSheet with #{stolen_record_ids.size} stolen records"
end

# --- ImpoundClaims: one submitted, one approved, one denied ---
impound_records = hogwarts.impound_records.reorder(:id).limit(3).to_a
if impound_records.any? && ImpoundClaim.where(organization: hogwarts).none?
  bike_submitting = hogwarts.bikes.where.not(id: impound_records.map(&:bike_id)).first ||
    user.bikes.first

  impound_records.zip(%w[submitting approved denied]).each do |record, status|
    next if record.blank?

    ImpoundClaim.create!(
      impound_record: record,
      organization: hogwarts,
      user: user,
      bike_submitting: bike_submitting,
      bike_claimed: record.bike,
      status: status,
      message: "I'm pretty sure this is my bike — I lost it last month near the address.",
      response_message: ((status != "submitting") ? "Please come by the office between 9-5 to retrieve it." : nil)
    )
    puts "  Created ImpoundClaim (#{status}) on impound_record ##{record.id}"
  end
end

# --- Transferred bike: needed for the `finished_registration_transferred`
# preview, which selects an unorganized, unclaimed bike that has a
# previous_ownership_id (i.e. was transferred to a new owner). ---
transferred_bike_exists = Bike.left_joins(:current_ownership)
  .where(ownerships: {claimed: false})
  .where(status: :status_with_owner).unorganized
  .where.not(ownerships: {previous_ownership_id: nil}).exists?

unless transferred_bike_exists
  bike = BikeServices::Creator.new.create_bike(
    BParam.create!(creator: user, params: {
      bike: {
        cycle_type: "bike",
        propulsion_type: "foot-pedal",
        serial_number: "TRANSFERRED01",
        manufacturer_id: Manufacturer.frame_makers.pluck(:id).sample,
        primary_frame_color_id: Color.pluck(:id).sample,
        rear_tire_narrow: "true",
        handlebar_type: HandlebarType.slugs.first,
        owner_email: "previous-owner@example.com"
      }
    })
  )
  raise "Transferred bike creation failed" if bike.errors.any?

  BikeServices::Updator.new(
    user: user,
    bike: bike,
    permitted_params: {bike: {owner_email: "new-owner@example.com"}}.as_json
  ).update_available_attributes
  CallbackJob::AfterBikeSaveJob.new.perform(bike.id, true, true)
  puts "  Created transferred bike ##{bike.id}"
end

puts "Organized mailer preview records seeded successfully!"
