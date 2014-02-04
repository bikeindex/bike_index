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
  {name: "Fork", cgroup: Cgroup.find_by_name('Frame and fork').id},
  {name: "Rear suspension", cgroup: Cgroup.find_by_name('Frame and fork').id},
  {name: "Headset", cgroup: Cgroup.find_by_name('Frame and fork').id},
  {name: "Rim", cgroup: Cgroup.find_by_name('Wheels').id, has_multiple: true},
  {name: "Axle nuts", cgroup: Cgroup.find_by_name('Wheels').id, has_multiple: true},
  {name: "Hub", cgroup: Cgroup.find_by_name('Wheels').id, has_multiple: true},
  {name: "Spokes", cgroup: Cgroup.find_by_name('Wheels').id, has_multiple: true},
  {name: "Tube", cgroup: Cgroup.find_by_name('Wheels').id, has_multiple: true},
  {name: "Tire", cgroup: Cgroup.find_by_name('Wheels').id, has_multiple: true},
  {name: "Wheel complete", cgroup: Cgroup.find_by_name('Wheels').id, has_multiple: true},
  {name: "Brake lever", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id, has_multiple: true},
  {name: "Shift and brake lever", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id, has_multiple: true},
  {name: "Brake Caliper", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id, has_multiple: true},
  {name: "Brake rotor", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id, has_multiple: true},
  {name: "Brake cable", cgroup: Cgroup.find_by_name('Drivetrain and brakes') .id},
  {name: "Shift cable", cgroup: Cgroup.find_by_name('Drivetrain and brakes') .id},
  {name: "Brake pad", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id, has_multiple: true},
  {name: "Chain", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Shifter", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id, has_multiple: true},
  {name: "Front derailleur", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Rear derailleur", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Three piece driver", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Cassette", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Freewheel", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Crankset", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Bottom Bracket", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Pedals", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  # {name: "Freewheel", cgroup: Cgroup.find_by_name('Drivetrain and brakes').id},
  {name: "Rear rack", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Handlebars", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Seat", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Computer", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Pegs", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Hub Guard", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Handlebar tape", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Toe clips", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Grips", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Seat post", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Other", cgroup: Cgroup.find_by_name('Additional parts').id},
  {name: "Water bottle cage", cgroup: Cgroup.find_by_name('Additional parts').id}
]
ctypes.each do |component_type|
  ct = Ctype.create(name: component_type[:name], cgroup_id: component_type[:cgroup])
  if component_type[:has_multiple]
    ct.has_multiple = true
  end
  ct.save
end


Automating bike registration with Google Apps script and the Bike Index API