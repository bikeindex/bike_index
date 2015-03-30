# Seed the cycle types
cycle_types = [
  { name: 'Bike', slug: 'bike' },
  { name: 'Tandem', slug: 'tandem' },
  { name: 'Unicycle', slug: 'unicycle' },
  { name: 'Tricycle', slug: 'tricycle' },
  { name: 'Recumbent', slug: 'recumbent' },
  { name: 'Pedi Cab', slug: 'pedi-cab' },
  { name: 'Cargo Bike (front storage)', slug: 'cargo' },
  { name: 'Cargo Bike (rear storage)', slug: 'cargo-rear' },
  { name: 'Cargo Tricycle (front storage)', slug: 'cargo-trike' },
  { name: 'Cargo Tricycle (rear storage)', slug: 'cargo-trike-rear' },
  { name: 'Bike Trailer', slug: 'trailer' },
  { name: 'Trail behind (half bike)', slug: 'trail-behind' },
  { name: 'Tall Bike', slug: 'tall-bike' },
  { name: 'Penny Farthing', slug: 'penny-farthing' },
  { name: 'Wheelchair', slug: 'wheelchair' },
  { name: 'Stroller', slug: 'stroller' }]
cycle_types.each do |ct|
  cycle_type = CycleType.create(name: ct[:name], slug: ct[:slug])
  cycle_type.save
end


# Seed the lock types

lock_types = ["U-lock", "Chain with lock", "Cable", "Locking skewer", "Other style"]
lock_types.each do |type_name|
  lock_type = LockType.create(name: type_name)
  lock_type.save
end

# Seed the colors
colors = [
  {:name=>"Black", :priority=>1, :display=>"<span class='sclr' style='background: #000'></span>"},
  {:name=>"Blue", :priority=>1, :display=>"<span class='sclr' style='background: #386ed2'></span>"},
  {:name=>"Brown", :priority=>1, :display=>"<span class='sclr' style='background: #734a22'></span>"},
  {:name=>"Green", :priority=>1, :display=>"<span class='sclr' style='background: #1ba100'></span>"},
  {:name=>"Orange", :priority=>1, :display=>"<span class='sclr' style='background: #ff8d1d'></span>"},
  {:name=>"Pink", :priority=>1, :display=>"<span class='sclr' style='background: #ff7dfd'></span>"},
  {:name=>"Purple", :priority=>1, :display=>"<span class='sclr' style='background: #a745c0'></span>"},
  {:name=>"Red", :priority=>1, :display=>"<span class='sclr' style='background: #ec1313'></span>"},
  {:name=>"Silver or Gray", :priority=>1, :display=>"<span class='sclr' style='background: #b0b0b0'></span>"},
  {:name=>"Stickers tape or other cover-up", :priority=>3, :display=>"<span class='sclr'>stckrs</span>"},
  {:name=>"Teal", :priority=>1, :display=>"<span class='sclr' style='background: #3bede7'></span>"},
  {:name=>"White", :priority=>1, :display=>"<span class='sclr' style='background: #fff'></span>"},
  {:name=>"Yellow or Gold", :priority=>1, :display=>"<span class='sclr' style='background: #fff44b'></span>"}
]
colors.each do |c|
  color = Color.create(name: c[:name], priority: c[:priority], display: c[:display])
  color.save
end

# Seed the handlebar types
handlebar_types = [
  { name: 'Flat or riser', slug: 'flat'},
  { name: 'Drop', slug: 'drop'},
  { name: 'Forward facing', slug: 'forward'},
  { name: 'Rear facing', slug: 'rearward'},
  { name: 'BMX style', slug: 'bmx'},
  { name: 'Not handlebars', slug: 'other'}]
handlebar_types.each do |h|
  handlebar_type = HandlebarType.create(name: h[:name], slug: h[:slug])
  handlebar_type.save
end

# Seed the Frame materials
frame_materials = [
  { name: 'Steel', slug: 'steel'},
  { name: 'Aluminum', slug: 'aluminum'},
  { name: 'Carbon or composite', slug: 'composite'},
  { name: 'Titanium', slug: 'titanium'},
  { name: 'Wood', slug: 'wood'}]
frame_materials.each do |m|
  frame_material = FrameMaterial.create(name: m[:name], slug: m[:slug])
  frame_material.save
end

# Seed the propulsion types
propulsions = ['Foot pedal', 'Hand pedal', 'Sail', 'Insufflation', 'Electric Assist', 'Electric throttle', 'Gas', 'Other style']
propulsions.each do |prop|
  propulsion_type = PropulsionType.create(name: prop)
  propulsion_type.slug = 'other' if prop == 'Other style'
  propulsion_type.save
end

# Seed the gear types

f_gear_types = [
  {name: '1', count: 1, internal: false, standard: true },
  {name: '2', count: 2, internal: false, standard: true },
  {name: '3', count: 3, internal: false, standard: true },
  {name: '2 internal', count: 2, internal: true},
  {name: '3 internal', count: 3, internal: true}
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
  {name: 'Continuously variable', count: 0, internal: true, standard: true},
  {name: 'Fixed', count: 1, internal: false},
]
  r_gear_types.each do |gear|
    r_gear_type = RearGearType.create(name: gear[:name], count: gear[:count], internal: gear[:internal], standard: gear[:standard])
    r_gear_type.save
  end