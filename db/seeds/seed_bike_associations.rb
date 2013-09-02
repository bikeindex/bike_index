# Seed the cycle types
cycle_types = ['Bike', 'Tandem', 'Unicycle', 'Tricycle', 'Recumbent', 'Pedi Cab', 'Cargo Bike (front storage)', 'Cargo Bike (rear storage)', 'Cargo Tricycle (front storage)', 'Cargo Tricycle (rear storage)', 'Bike Trailer', 'Tall Bike', 'Penny Farthing', 'Wheelchair', 'Other']
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
  {name: '1', count: 1, internal: false},
  {name: '2', count: 2, internal: false},
  {name: '3', count: 3, internal: false},
  {name: 'Internal', count: 1, internal: true},
  {name: 'Other style, internal: false'}
]
f_gear_types.each do |gear|
  f_gear_type = FrontGearType.create(name: gear[:name], count: gear[:count], internal: gear[:internal])
  f_gear_type.save
end
r_gear_types = [
  {name: '1', count: 1, internal: false},
  {name: '2', count: 2, internal: false},
  {name: '3', count: 3, internal: false},
  {name: '4', count: 4, internal: false},
  {name: '5', count: 5, internal: false},
  {name: '6', count: 6, internal: false},
  {name: '7', count: 7, internal: false},
  {name: '8', count: 8, internal: false},
  {name: '9', count: 9, internal: false},
  {name: '10', count: 10, internal: false},
  {name: '11', count: 11, internal: false},
  {name: '12', count: 12, internal: false},
  {name: 'Fixed', count: 1, internal: false},
  {name: 'Coaster Brake', count: 1, internal: false},
  {name: 'Other style', internal: false}
]
r_gear_types.each do |gear|
  r_gear_type = RearGearType.create(name: gear[:name], count: gear[:count], internal: gear[:internal])
  r_gear_type.save
end