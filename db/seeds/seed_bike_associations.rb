# Seed the cycle types
cycle_types = ['Bike', 'Tandem', 'Unicycle', 'Tricycle', 'Recumbent', 'Pedi Cab', 'Cargo Bike (front storage)', 'Cargo Bike (rear storage)', 'Cargo Tricycle (front storage)', 'Cargo Tricycle (rear storage)', 'Bike Trailer', 'Tall Bike', 'Penny Farthing', 'Wheelchair', 'Stroller', 'Other']
cycle_types.each do |type_name|
  cycle_type = CycleType.create(name: type_name)
  cycle_type.save
end


# Seed the lock types

lock_types = ["U-lock", "Chain with lock", "Cable", "Locking skewers", "Other style"]
lock_types.each do |type_name|
  lock_type = LockType.create(name: type_name)
  lock_type.save
end

# Seed the colors
colors = [
  { name: 'Black', priority: 1 },
  { name: 'White', priority: 1 },
  { name: 'Gray or Silver', priority: 1 },
  { name: 'Red', priority: 1 },
  { name: 'Green', priority: 1 },
  { name: 'Blue', priority: 1 },
  { name: 'Purple', priority: 1 },
  { name: 'Pink', priority: 1 },
  { name: 'Orange', priority: 1 },
  { name: 'Brown', priority: 1 },
  { name: 'Raw metal', priority: 2 },
  { name: 'Yellow or Gold', priority: 1 },
  { name: 'Stickers, tape or other cover-up', priority: 3 }
]
colors.each do |c|
  color = Color.create(name: c[:name], priority: c[:priority])
  color.save
end

# Seed the handlebar types
handlebar_types = ['Flat', 'Drop', 'Forward facing', 'Rear facing', 'BMX Style', 'Other style']
handlebar_types.each do |type_name|
  handlebar_type = HandlebarType.create(name: type_name)
  handlebar_type.save
end

# Seed the Frame materials
frame_materials = ['Steel', 'Aluminium', 'Composite', 'Titanium', 'Other style']
frame_materials.each do |material|
  frame_material = FrameMaterial.create(name: material)
  frame_material.save
end

# Seed the propulsion types
propulsions = ['Foot pedal', 'Hand pedal', 'Sail', 'Insufflation', 'Electric Assist', 'Electric throttle', 'Gas', 'Other style']
propulsions.each do |prop|
  propulsion_type = PropulsionType.create(name: prop)
  propulsion_type.save
end

# Seed the gear types

f_gear_types = [
  {name: '1', count: 1, internal: false, standard: true },
  {name: '2', count: 2, internal: false, standard: true },
  {name: '3', count: 3, internal: false, standard: true },
  {name: 'Internal 2', count: 2, internal: true},
  {name: 'Internal 3', count: 3, internal: true},
  {name: 'Fixed', count: 1, internal: false}
]
f_gear_types.each do |gear|
  f_gear_type = FrontGearType.create(name: gear[:name], count: gear[:count], internal: gear[:internal], standard: gear[:standard])
  f_gear_type.save
end
r_gear_types = [
  {name: '1', count: 1, internal: false, standard: true},
  {name: '2', count: 2, internal: false, standard: true},
  {name: '3', count: 3, internal: false, standard: true},
  {name: '4', count: 4, internal: false, standard: true},
  {name: '5', count: 5, internal: false, standard: true},
  {name: '6', count: 6, internal: false, standard: true},
  {name: '7', count: 7, internal: false, standard: true},
  {name: '8', count: 8, internal: false, standard: true},
  {name: '9', count: 9, internal: false, standard: true},
  {name: '10', count: 10, internal: false, standard: true},
  {name: '11', count: 11, internal: false, standard: true},
  {name: '12', count: 12, internal: false, standard: true},
  {name: '1 internal', count: 1, internal: true, standard: false},
  {name: '2 internal', count: 2, internal: true, standard: false},
  {name: '3 internal', count: 3, internal: true, standard: false},
  {name: '4 internal', count: 4, internal: true, standard: false},
  {name: '5 internal', count: 5, internal: true, standard: false},
  {name: '6 internal', count: 6, internal: true, standard: false},
  {name: '7 internal', count: 7, internal: true, standard: false},
  {name: '8 internal', count: 8, internal: true, standard: false},
  {name: '9 internal', count: 9, internal: true, standard: false},
  {name: '10 internal', count: 10, internal: true, standard: false},
  {name: '11 internal', count: 11, internal: true, standard: false},
  {name: '12 internal', count: 12, internal: true, standard: false},
  {name: 'Continuously variable', count: 0, internal: true, standard: false},
  {name: 'Fixed', count: 1, internal: false},
]
  r_gear_types.each do |gear|
    r_gear_type = RearGearType.create(name: gear[:name], count: gear[:count], internal: gear[:internal], standard: gear[:standard])
    r_gear_type.save
  end