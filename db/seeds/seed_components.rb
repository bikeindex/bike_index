# Seed the component groups
cgroups = [{name: "Frame and Fork", description: "Frame and fork. Also headset.", priority: 1},
  {name: "Wheels", description: "wheels and everything to do with them (including freehub bodies, not including cassettes).", priority: 2},
  {name: "Drivetrain and Brakes", description: "Shifters, cranks, chain, brake levers brake calipers.", priority: 3},
  {name: "Additional parts", description: "Seat, handlebars, accessories (computer, rack, lights, etc).", priority: 4}]
cgroups.each do |component_group|
  cg = Cgroup.create(name: component_group[:name], description: component_group[:description], priority: component_group[:priority])
  cg.save
end

# Seed the component types
ctypes = [
  {name: "unknown", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Water Bottle Cage", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Stem", secondary_name: "Gooseneck", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Bashguard/Chain Guide", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Fairing", has_multiple: false, cgroup_id: Cgroup.find_by_name("Frame and Fork").id},
  {name: "Lights", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Bell/Noisemaker", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Basket", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Chain Tensioners", secondary_name: "Chain tugs", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Derailleur", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Training Wheels", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Bottom Bracket", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Brake", has_multiple: true, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Hub Guard", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Generator/Dynamo", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Handlebar", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Wheel", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id},
  {name: "Saddle", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Rim", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id},
  {name: "Axle Nuts", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id},
  {name: "Hub", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id},
  {name: "Spokes", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id},
  {name: "Tube", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id},
  {name: "Tire", has_multiple: true, cgroup_id: Cgroup.find_by_name("Wheels").id},
  {name: "Brake Lever", has_multiple: true, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Shift and Brake Lever", has_multiple: true, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Brake Rotor", has_multiple: true, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Brake Pad", has_multiple: true, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Shifter", has_multiple: true, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Fork", has_multiple: false, cgroup_id: Cgroup.find_by_name("Frame and Fork").id},
  {name: "Rear Suspension", has_multiple: false, cgroup_id: Cgroup.find_by_name("Frame and Fork").id},
  {name: "Headset", has_multiple: false, cgroup_id: Cgroup.find_by_name("Frame and Fork").id},
  {name: "Brake Cable", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Shift Cable", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Chain", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Chainrings", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Cog/Cassette/Freewheel", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Crankset", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Pedals", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Computer", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Pegs", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Toe Clips", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Grips/Tape", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Seatpost Clamp", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Detangler", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Kickstand", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Rack", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Seatpost", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Fender", has_multiple: true, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Aero Bars/Extensions/Bar Ends", secondary_name: "Aero bars", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Ebike Battery", secondary_name: "Electric Bike Battery", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Ebike Motor", secondary_name: "Electric Bike motor", has_multiple: false, cgroup_id: Cgroup.find_by_name("Drivetrain and Brakes").id},
  {name: "Pannier", secondary_name: "Rack bag", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Frame Bag", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Cargo Bike Side Rails", secondary_name: "Cargo bike Monkey bars", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Handlebar Bag", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Seat Bag", secondary_name: "saddle bag", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Top Tube Bag", secondary_name: "bento box", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id},
  {name: "Child Seat", has_multiple: false, cgroup_id: Cgroup.find_by_name("Additional parts").id}
]
ctypes.each do |component_type|
  ct = Ctype.create(name: component_type[:name], secondary_name: component_type[:secondary_name], cgroup_id: component_type[:cgroup_id])
  if component_type[:has_multiple]
    ct.has_multiple = true
  end
  ct.save
end
