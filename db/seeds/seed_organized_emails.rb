# Seed records required for the OrganizedMailer previews
# (`/rails/mailers/organized_mailer/<kind>`) and for /organizations/hogwarts/emails
# to render. Each preview action fetches its target via `Model.last`/`Model.scope.last`,
# so we need at least one of each kind tied to Hogwarts.

hogwarts = Organization.find_by_name("Hogwarts")
member = User.find_by_email("member@bikeindex.org")
user = User.find_by_email("user@bikeindex.org")

raise "missing Hogwarts org or test users" if hogwarts.blank? || member.blank? || user.blank?

# --- Mail snippets ---
# Bodies for the "structural" snippets (header/welcome/footer/security/partial_registration)
# are copied verbatim from the dev database's Hogwarts records. The notification-kind
# snippets exercise the `organization_message_snippet` paths in OrganizedMailer previews.
snippets = {
  "header" => {
    is_enabled: true,
    body: <<~HTML
      <div class="organized-partnership-header">
        <p>
          <img src="https://files.bikeindex.org/uploads/Pu/479405/Daco_4242902.png">
        </p>
        <hr>
      </div>
    HTML
  },
  "welcome" => {
    is_enabled: true,
    body: <<~HTML
      <p style="color: purple; margin: 20px 0; text-align: center;">
        <strong>We can add text here!</strong> - this is the <em>welcome</em>  snippet
      </p>
    HTML
  },
  "footer" => {
    is_enabled: true,
    body: <<~HTML
      <p style="color: purple; margin: 20px 0; text-align: center;">
        <strong>We can add text here!</strong> - this is the <em>footer</em> snippet
      </p>
    HTML
  },
  "security" => {
    is_enabled: false,
    body: <<~HTML
      <p style="color: purple; margin: 20px 0; text-align: center;">
        <strong>We can replace the existing text here!</strong>
        <br>This section normally has the drawing of a bike and explains how to lock up (it starts with "PROTECT YOUR BIKE BY FOLLOWING THESE LOCKING GUIDELINES.")
        <br>- this is the <em>Security</em> snippet
      </p>
    HTML
  },
  "partial_registration" => {
    is_enabled: true,
    body: <<~HTML
      <p style="color: purple; margin: 20px 0; text-align: center;">
        <strong>We can add text here!</strong> - this is the <em>partial</em> snippet
      </p>
    HTML
  },
  "appears_abandoned_notification" => {
    is_enabled: true,
    subject: "Your bike appears abandoned at Hogwarts",
    body: <<~HTML
      <p>Greetings from the Hogwarts groundskeeper,</p>
      <p>During a recent sweep of the castle bike racks your broomstick-substitute appeared to have a flat tire, excessive rust, missing parts, or other signs that it has not been ridden in some time.</p>
      <p>Left as is, it risks being impounded by Mr. Filch.</p>
      <p>Hogwarts grounds regulations require bikes to be in working order and used regularly. Please return to your bike within two weeks, otherwise it will be impounded.</p>
      <p>Yours,<br>Hogwarts Bike Programme</p>
    HTML
  },
  "parked_incorrectly_notification" => {
    is_enabled: true,
    subject: "Your bike is improperly parked at Hogwarts",
    body: <<~HTML
      <p>Greetings,</p>
      <p>Your bike is improperly parked and must be moved to a designated rack within 24 hours or it risks being impounded. Hogwarts regulations state that bikes must be locked to bike racks &mdash; the Whomping Willow does not count.</p>
      <p>If your bike is impounded, contact the Hogwarts Bike Programme for next steps.</p>
      <p>Sincerely,<br>Hogwarts Bike Programme</p>
    HTML
  },
  "impound_notification" => {
    is_enabled: true,
    subject: "Your bike has been impounded at Hogwarts",
    body: <<~HTML
      <p>Hello,</p>
      <p>Your bike has been impounded by Mr. Filch due to one or more infractions of Hogwarts bike regulations. Please contact the Hogwarts Bike Programme for next steps to resolve this.</p>
      <p>Per Wizarding law, bikes not claimed one year after impoundment may be donated to area Hogsmeade non-profit organizations for repair and reuse.</p>
      <p>Sincerely,<br>Hogwarts Bike Programme</p>
    HTML
  },
  "other_parking_notification" => {
    is_enabled: true,
    subject: "Bike registration needed at Hogwarts",
    body: <<~HTML
      <p>If you are missing a registration sticker or need to re-register your bike, please visit the Hogwarts Bike Programme office in the Owlery courtyard.</p>
    HTML
  },
  "graduated_notification" => {
    is_enabled: true,
    subject: "Renew your bike registration with Hogwarts",
    body: <<~HTML
      <p>Time to renew your registration with Hogwarts!</p>
      <p>If you are remaining at the castle next term, click the button below to keep your registration current. Your registration sticker will remain valid.</p>
      <p>If you are graduating &mdash; congratulations! &mdash; your bike registration will transfer to the general Bike Index registry.</p>
    HTML
  },
  "impound_claim_approved" => {
    is_enabled: true,
    subject: "Your impound claim has been approved",
    body: <<~HTML
      <p>Your impound claim was approved. Please come to the Hogwarts Bike Programme office between 9-5 to retrieve your bike. Bring photo ID (or your house badge).</p>
    HTML
  },
  "impound_claim_denied" => {
    is_enabled: true,
    subject: "Your impound claim has been denied",
    body: <<~HTML
      <p>Your impound claim was denied. Reply to this email if you would like to appeal &mdash; the Hogwarts Bike Programme office will review your case.</p>
    HTML
  }
}

snippets.each do |kind, attrs|
  snippet = hogwarts.mail_snippets.where(kind:).first_or_initialize
  snippet.update!(attrs)
end

# --- OrganizationStolenMessage: enable so it renders in stolen-bike emails ---
OrganizationStolenMessage.for(hogwarts).update!(
  is_enabled: true,
  body: "If your bike was stolen near Hogwarts, please report the theft to the Auror Office at the Ministry of Magic. Include a detailed description and any photos you have.",
  search_radius_miles: 25
)

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

puts "Organized email seed records seeded successfully!"
