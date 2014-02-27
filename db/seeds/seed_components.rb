# Seed the component groups
cgroups = [ {name: "Frame and fork", description: "Frame and fork. Also headset." },
  {name: "Wheels", description: "wheels and everything to do with them (including freehub bodies, not including cassettes)." },
  {name: "Drivetrain and brakes", description: "Shifters, cranks, chain, brake levers brake calipers." },
  {name: "Additional parts", description: "Seat, handlebars, accessories (computer, rack, lights, etc)." }]
cgroups.each do |component_group|
  cg = Cgroup.create(name: component_group[:name], description: component_group[:description])
  cg.save
end

# Seed the component types
ctypes = [
  { name: "other", slug: "other", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "unknown", slug: "unknown", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "water bottle cage", slug: "water-bottle-cage", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "stem", slug: "stem", secondary_name: "Gooseneck",  has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "chainring bashguard", slug: "chainring-bashguard", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "fairing", slug: "fairing", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "lights", slug: "light", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "bell", slug: "bell", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "basket", slug: "basket", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "chain tensioners", slug: "chain-tensioners", secondary_name: "Chain tugs",  has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "derailleur", slug: "derailleur", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "training wheels", slug: "training-wheels", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "bottom bracket", slug: "bottom-bracket", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "brake", slug: "brake", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "hub guard", slug: "hub-guard", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "dynamo", slug: "dynamo", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "handlebar", slug: "handlebar", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "wheel", slug: "wheel", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "saddle", slug: "saddle", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "rim", slug: "rim", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "axle nuts", slug: "axle-nuts", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "hub", slug: "hub", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "spokes", slug: "spokes", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "tube", slug: "tube", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "tire", slug: "tire", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "brake lever", slug: "brake-lever", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "shift and brake lever", slug: "shift-and-brake-lever", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "brake rotor", slug: "brake-rotor", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "brake pad", slug: "brake-pad", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "shifter", slug: "shifter", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "fork", slug: "fork", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "rear suspension", slug: "rear-suspension", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "headset", slug: "headset", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "brake cable", slug: "brake-cable", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "shift cable", slug: "shift-cable", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "chain", slug: "chain", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "cassette", slug: "cassette", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "crankset", slug: "crankset", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "pedals", slug: "pedals", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "computer", slug: "computer", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "pegs", slug: "pegs", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "toe clips", slug: "toe-clips", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "grips/tape", slug: "gripstape", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "seatpost clamp", slug: "seatpost-clamp", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "detangler", slug: "detangler", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "kickstand", slug: "kickstand", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "rack", slug: "rear-rack", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "seatpost", slug: "seatpost", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "fender", slug: "fender", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "aero bars/extensions/bar ends", slug: "aero-barsextensionsbar-ends", secondary_name: "Aero bars",  has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id}
]
ctypes.each do |component_type|
  ct = Ctype.create(name: component_type[:name], cgroup_id: component_type[:cgroup_id])
  if component_type[:has_multiple]
 ct.has_multiple = true
  end
  ct.save
end