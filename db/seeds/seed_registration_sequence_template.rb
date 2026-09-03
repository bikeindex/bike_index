# Seeds the global RegistrationSequence template (org drafts are cloned from it). This is the
# e-vehicle acknowledgment sequence from kelsey_redesign/register-your-bike.html, verbatim —
# its three screens, their headings and their checkbox rules. The bullets become each page's
# `body`, a single HTML list authored in the Lexxy rich-text editor on the form.
#
# The prototype gates two of these behind its "school" props; Brakebills (the seeded school)
# has both on, so they're included: the last rule of each of the first two pages is the
# school's own, and the third page is entirely the school's.
default_pages = [
  {
    title: "Batteries & charging",
    heading: "Looks like you have an e-vehicle!",
    subtitle: "We have a few additional campus safety rules to go over before you can complete registration.",
    bullet_points: [
      "I will charge only with the manufacturer's charger — never unattended, overnight, or in a hallway, stairwell, or exit route.",
      "I will use only manufacturer-spec batteries certified to UL 2849 / UL 2271 (or equivalent). No aftermarket or uncertified batteries, and no self-modification.",
      "I will store batteries only in approved locations, keep them in safe operating condition, and stop using &amp; report any damaged, swollen, or overheating battery.",
      "I will charge at an approved campus charging locker and register my battery serial number with Campus Safety."
    ]
  },
  {
    title: "Riding practices",
    subtitle: "A few commitments that keep you and everyone on campus safe.",
    bullet_points: [
      "I will wear a CPSC-certified helmet, obey posted limits (max 15 mph, walking pace in crowds), and ride only where the bike's class is allowed.",
      "I will follow all traffic laws, yield to pedestrians, signal turns, and never ride impaired, distracted, or with earbuds in both ears.",
      "I will park only in designated areas without blocking paths, lock my bike, and stop to help &amp; report any collision.",
      "I will complete the campus e-bike orientation module and keep my registration decal visible at all times."
    ]
  },
  {
    title: "Campus-specific rules",
    subtitle: "Your school has a couple of additional rules for riding on campus.",
    organization_specific: true,
    bullet_points: [
      "I will ride only on designated campus paths and dismount in all posted dismount zones.",
      "I will park only in campus e-vehicle corrals — never at pedestrian entrances or building exits."
    ]
  }
]

# faq_url is the ⓘ on every acknowledgment page; an organization can point it at its own
# policy page, the Bike Index FAQ is the default
template = RegistrationSequence.create!(acknowledgment_text: RegistrationSequence::DEFAULT_ACKNOWLEDGMENT_TEXT,
  faq_url: "/info/#{Blog.e_vehicle_acknowledgment_faq}")

default_pages.each_with_index do |attributes, index|
  template.registration_sequence_pages.create!(listing_order: index, title: attributes[:title],
    heading: attributes[:heading], subtitle: attributes[:subtitle],
    organization_specific: attributes[:organization_specific].present?,
    body: "<ul>#{attributes[:bullet_points].map { |bullet| "<li>#{bullet}</li>" }.join}</ul>")
end
# Organizations clone the live template, so the seeded one has to be activated
template.make_active!

# Brakebills registers e-vehicles, so give it a live sequence — without an active one
# the acknowledgment pages never appear, and the flow can't be seen in development.
brakebills = Organization.find_by_name("Brakebills")
if brakebills.present?
  sequence = RegistrationSequence.draft_for(brakebills)
  # The school names its own page, the way an organization would in the editor - the
  # template can't, since it's cloned by every organization
  sequence.registration_sequence_pages.where(organization_specific: true)
    .update_all(heading: "#{brakebills.short_name} campus policies")
  sequence.make_active!
  puts "Registration sequence activated for Brakebills: #{sequence.registration_sequence_pages.count} pages\n"
end
