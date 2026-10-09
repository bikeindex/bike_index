# Seeds the global RegistrationSequence template - the e-vehicle safety rules every e-vehicle
# registration without an organization sequence of its own agrees to, and that organization
# drafts are cloned from. The bullets become each page's `body`, a single HTML list authored
# in the Lexxy rich-text editor on the form.
default_pages = [
  {
    title: "Riding an e-vehicle",
    heading: "Looks like you have an e-vehicle!",
    subtitle: "We love e-bikes, e-scooters, and everything else that gets people out of cars. Electric rides are also a little different from regular bikes, so here are a few things worth knowing before you head out.",
    bullet_points: [
      "<strong>Know your class.</strong> Most US e-bikes are Class 1 (pedal-assist to 20 mph), Class 2 (throttle to 20 mph), or Class 3 (pedal-assist to 28 mph). Your class decides where you're allowed to ride, so check the sticker on your frame.",
      "<strong>More than 750W or 28 mph? It may not be an e-bike.</strong> In most states, a vehicle that exceeds e-bike limits is legally a moped or motorcycle, which can mean a license, plates, and insurance. Unlocked or \"off-road mode\" bikes count too.",
      "<strong>Heavier and faster changes the math.</strong> E-vehicles weigh more and get up to speed quicker, so stopping takes longer and other people misjudge how fast you're closing. Give pedestrians extra room and slow down where it's crowded.",
      "<strong>Helmets and local rules.</strong> A good helmet is always smart, and some places require one for Class 3 riders or anyone under a certain age. Rules on paths, sidewalks, and age limits vary by city, so look up yours."
    ]
  },
  {
    title: "Batteries & charging",
    heading: "Batteries, charging, and keeping it yours",
    subtitle: "Lithium-ion batteries are safe when they're built and treated right, and the rare fires almost always trace back to cheap, damaged, or mismatched gear. A few habits keep you, your home, and your neighbors safe.",
    bullet_points: [
      "<strong>Look for UL certification.</strong> UL 2849 (e-bikes), UL 2272 (scooters, boards, one-wheels), and UL 2271 (batteries) mean the system was tested as a whole. Use the charger and replacement batteries your manufacturer specifies.",
      "<strong>Charge where you'd notice.</strong> Charge while you're home and awake, on a hard surface, away from your door or stairway. Unplug once it's full.",
      "<strong>Retire a sick battery.</strong> If it's swollen, dented, leaking, smells odd, or gets hot, stop using it. Most cities and bike shops can point you to a battery recycling drop-off; never put lithium batteries in the trash.",
      "<strong>E-bikes are theft magnets.</strong> Lock the frame to something solid with a quality U-lock or chain, and take the battery inside when you can. Add your battery and motor serial numbers and a few photos to this registration, which makes recovery far more likely if it's stolen."
    ]
  }
]

# faq_url is the ⓘ on every acknowledgment page; an organization can point it at its own
# policy page, the Bike Index FAQ is the default
template = RegistrationSequence.create!(faq_url: "/info/#{Blog.e_vehicle_acknowledgment_faq}",
  acknowledgment_text: "have read and understood the e-vehicle safety information above.")

default_pages.each_with_index do |attributes, index|
  template.registration_sequence_pages.create!(listing_order: index, title: attributes[:title],
    heading: attributes[:heading], subtitle: attributes[:subtitle],
    body: "<ul>#{attributes[:bullet_points].map { |bullet| "<li>#{bullet}</li>" }.join}</ul>")
end
# Organizations clone the live template, so the seeded one has to be activated
template.make_active!

# Brakebills registers e-vehicles, so give it a live sequence of its own, with a campus page
# the way an organization would add one in the editor
brakebills = Organization.find_by_name("Brakebills")
if brakebills.present?
  sequence = RegistrationSequence.draft_for(brakebills)
  sequence.registration_sequence_pages.create!(title: "Campus-specific rules", organization_specific: true,
    heading: "#{brakebills.short_name} campus policies",
    subtitle: "Your school has a couple of additional rules for riding on campus.",
    body: "<ul><li>I will ride only on designated campus paths and dismount in all posted dismount zones.</li>" \
      "<li>I will park only in campus e-vehicle corrals — never at pedestrian entrances or building exits.</li></ul>")
  sequence.make_active!
  puts "Registration sequence activated for Brakebills: #{sequence.registration_sequence_pages.count} pages\n"

  # All but one of the e-vehicles, so a registration shows both with and without an acknowledgment
  acknowledged = brakebills.bikes.motorized.order(:id).to_a[0...-1]
  acknowledged.each do |bike|
    SeedHelpers.tick
    RegistrationSequenceAcknowledgment.create!(registration_sequence: sequence, bike:, user: bike.creator,
      owner_email: bike.owner_email, acknowledged_at: Time.current)
  end
  puts "Acknowledged the Brakebills registration sequence for #{acknowledged.count} e-vehicles\n"
end
