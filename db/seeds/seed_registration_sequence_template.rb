# Seeds the global RegistrationSequence template (org drafts are cloned from it). The template's
# pages live in the database; these are the default e-vehicle safety attestation pages a fresh
# install starts with. The bullets become each page's `body`, a single HTML list authored in the
# Lexxy rich-text editor on the form.
default_pages = [
  {
    title: "Battery & charging",
    subtitle: "The single biggest cause of e-bike fires on campus is unsafe charging. These commitments keep you and your hallmates safe.",
    bullet_points: [
      "Only charge with the manufacturer's charger or an approved replacement matching my vehicle's voltage and amperage.",
      "Not leave my e-vehicle charging unattended for extended periods, and never charge it overnight while I'm asleep. <em>Why: most lithium-ion fires happen between 1–5am when no one notices early warning signs.</em>",
      "Not charge in a hallway, stairwell, exit, or fire-escape route.",
      "Stop using and immediately report any battery showing damage, swelling, unusual heat, discoloration, or odor.",
      "Not charge or store my e-vehicle in a residence hall room or campus building unless it's a designated charging location.",
      "Not charge using an extension cord, multi-outlet adapter, or power strip."
    ]
  },
  {
    title: "Batteries & replacements",
    subtitle: "Aftermarket and uncertified batteries are the #1 source of catastrophic e-bike fires. Stick to certified.",
    bullet_points: [
      "Only use batteries compatible with my vehicle's manufacturer specifications and, where available, certified to UL 2849, UL 2271, or equivalent UL/CE/EN standards.",
      "Acknowledge that aftermarket or uncertified batteries are prohibited on university property. <em>Bike Index runs crowd-sourced e-vehicle audits — your battery's certification is on file.</em>",
      "Not modify, repair, or disassemble my battery or electrical system on my own."
    ]
  },
  {
    title: "Storage & maintenance",
    subtitle: "Where you park overnight matters. So does keeping your bike road-ready.",
    bullet_points: [
      "Store my e-vehicle only in approved locations — bike rooms, racks, or storage facilities — never in stairwells, hallways, dorm rooms, or lobbies.",
      "Not leave it where extreme heat, prolonged sunlight, or water could damage the battery.",
      "Have my battery and electrical system inspected by a qualified technician before charging or riding again after any collision or damage.",
      "Keep my e-vehicle in safe operating condition — working brakes, lights, and tires.",
      "Notify the university if I sell, transfer, or permanently remove my e-vehicle from campus."
    ]
  },
  {
    title: "Helmet, speed & class",
    subtitle: "The basics that make the biggest difference on campus paths.",
    bullet_points: [
      "Wear a properly fitted, CPSC-certified helmet every time I ride on or near campus, no matter how short the trip.",
      "Acknowledge that helmet use may be required by state law and is required by university policy as a condition of registration.",
      "Operate my e-bike only in areas and on paths permitted for its class (Class 1, 2, or 3) under university policy and state law.",
      "Observe posted speed limits, not exceed 15 mph on campus paths, and slow to walking pace (3–5 mph) in crowded pedestrian areas.",
      "Not modify my e-vehicle to exceed its manufacturer-rated speed or power output."
    ]
  },
  {
    title: "Rules of the road & campus paths",
    subtitle: "Pedestrians always come first.",
    bullet_points: [
      "Obey all applicable traffic laws, signals, and signage — my e-vehicle is a vehicle under state law.",
      "Yield to pedestrians at all times on shared paths, crosswalks, and building entrances.",
      "Ride in designated bike lanes or on the right side of the roadway, and not ride on sidewalks where prohibited.",
      "Use hand or electronic signals when turning or stopping, and use a bell or verbal alert when passing.",
      "Not ride side-by-side with another rider in a way that blocks the path."
    ]
  },
  {
    title: "Impairment & distraction",
    subtitle: "If you wouldn't drive a car like this, don't ride your e-bike like this either.",
    bullet_points: [
      "Not operate my e-vehicle while under the influence of alcohol, cannabis, or any substance that could impair my judgment or reaction time.",
      "Not use a handheld phone or other device while riding. I'll stop safely before using my phone.",
      "Not wear headphones or earbuds in both ears while riding — I need to hear traffic, pedestrians, and emergency signals.",
      "Not carry a passenger unless my vehicle is specifically designed and rated for two riders.",
      "Not carry loads that obstruct my steering, visibility, or braking."
    ]
  },
  {
    title: "Parking & incidents",
    subtitle: "Last set — promise. Parking, lockup, and what to do if something goes wrong.",
    bullet_points: [
      "Park only in designated bike parking areas; never block ramps, doorways, pedestrian paths, or accessible routes.",
      "Secure my e-vehicle with an appropriate lock when parked, and not leave it in unauthorized areas.",
      "Stop, render assistance or call for help, and report to campus safety if I'm involved in or witness a collision.",
      "Acknowledge that violating these rules may result in loss of registration, fines, or disciplinary action under the student code of conduct."
    ]
  }
]

template = RegistrationSequence.template

default_pages.each_with_index do |attributes, index|
  template.registration_sequence_pages.find_or_create_by!(listing_order: index) do |new_page|
    new_page.title = attributes[:title]
    new_page.subtitle = attributes[:subtitle]
    new_page.body = "<ul>#{attributes[:bullet_points].map { |bullet| "<li>#{bullet}</li>" }.join}</ul>"
  end
end
