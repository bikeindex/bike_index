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
  { name: "other", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "unknown", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "water bottle cage", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "stem", secondary_name: "Gooseneck",  has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "bashguard/chain guide", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "fairing", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "lights", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "bell", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "basket", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "chain tensioners", secondary_name: "Chain tugs",  has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "derailleur", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "training wheels", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "bottom bracket", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "brake", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "hub guard", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "generator/dynamo", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "handlebar", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "wheel", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "saddle", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "rim", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "axle nuts", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "hub", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "spokes", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "tube", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "tire", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id },
  { name: "brake lever", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "shift and brake lever", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "brake rotor", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "brake pad", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "shifter", has_multiple: true, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "fork", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "rear suspension", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "headset", has_multiple: false, cgroup_id: Cgroup.find_by_name('Frame and fork').id },
  { name: "brake cable", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "shift cable", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "chain", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "cassette", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "crankset", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "pedals", has_multiple: false, cgroup_id: Cgroup.find_by_name('Drivetrain and brakes').id },
  { name: "computer", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "pegs", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "toe clips", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "grips/tape", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "seatpost clamp", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "detangler", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "kickstand", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "rack", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "seatpost", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "fender", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id },
  { name: "aero bars/extensions/bar ends", secondary_name: "Aero bars",  has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id}
]
ctypes.each do |component_type|
  ct = Ctype.create(name: component_type[:name], cgroup_id: component_type[:cgroup_id])
  if component_type[:has_multiple]
 ct.has_multiple = true
  end
  ct.save
end