# Seed the lock types

lock_types = ['U-lock', 'Chain with lock', 'Cable', 'Locking skewer', 'Other style']
lock_types.each do |type_name|
  lock_type = LockType.create(name: type_name)
  lock_type.save
end

# Seed the colors
colors = [
  { name: 'Black', priority: 1, display: '#000' },
  { name: 'Blue', priority: 1, display: '#386ed2' },
  { name: 'Brown', priority: 1, display: '#734a22' },
  { name: 'Green', priority: 1, display: '#1ba100' },
  { name: 'Orange', priority: 1, display: '#ff8d1d' },
  { name: 'Pink', priority: 1, display: '#ff7dfd' },
  { name: 'Purple', priority: 1, display: '#a745c0' },
  { name: 'Red', priority: 1, display: '#ec1313' },
  { name: 'Silver, Gray or Bare Metal', priority: 1, display: '#b0b0b0' },
  { name: 'Stickers tape or other cover-up', priority: 3, display: '#fff' },
  { name: 'Teal', priority: 1, display: '#3bede7' },
  { name: 'White', priority: 1, display: '#fff' },
  { name: 'Yellow or Gold', priority: 1, display: '#fff44b' }
]
colors.each do |c|
  color = Color.create(name: c[:name], priority: c[:priority], display: c[:display])
  color.save
end

# Seed the gear types

f_gear_types = [
  { name: '1', count: 1, internal: false, standard: true },
  { name: '2', count: 2, internal: false, standard: true },
  { name: '3', count: 3, internal: false, standard: true },
  { name: '2 internal', count: 2, internal: true },
  { name: '3 internal', count: 3, internal: true }
]
f_gear_types.each do |gear|
  f_gear_type = FrontGearType.create(name: gear[:name], count: gear[:count], internal: gear[:internal], standard: gear[:standard])
  f_gear_type.save
end
r_gear_types = [
  { name: '1', count: 1, internal: false, standard: true },
  { name: '2', count: 2, internal: false, standard: true },
  { name: '3', count: 3, internal: false, standard: true },
  { name: '4', count: 4, internal: false, standard: true },
  { name: '5', count: 5, internal: false, standard: true },
  { name: '6', count: 6, internal: false, standard: true },
  { name: '7', count: 7, internal: false, standard: true },
  { name: '8', count: 8, internal: false, standard: true },
  { name: '9', count: 9, internal: false, standard: true },
  { name: '10', count: 10, internal: false, standard: true },
  { name: '11', count: 11, internal: false, standard: true },
  { name: '12', count: 12, internal: false, standard: true },
  { name: '13', count: 13, internal: false, standard: true },
  { name: '14', count: 14, internal: false, standard: true },
  { name: '1 internal', count: 1, internal: true, standard: false },
  { name: '2 internal', count: 2, internal: true, standard: false },
  { name: '3 internal', count: 3, internal: true, standard: false },
  { name: '4 internal', count: 4, internal: true, standard: false },
  { name: '5 internal', count: 5, internal: true, standard: false },
  { name: '6 internal', count: 6, internal: true, standard: false },
  { name: '7 internal', count: 7, internal: true, standard: false },
  { name: '8 internal', count: 8, internal: true, standard: false },
  { name: '9 internal', count: 9, internal: true, standard: false },
  { name: '10 internal', count: 10, internal: true, standard: false },
  { name: '11 internal', count: 11, internal: true, standard: false },
  { name: '12 internal', count: 12, internal: true, standard: false },
  { name: '13 internal', count: 13, internal: true, standard: false },
  { name: '14 internal', count: 14, internal: true, standard: false },
  { name: 'Continuously variable', count: 0, internal: true, standard: true },
  { name: 'Fixed', count: 1, internal: false }
]
r_gear_types.each do |gear|
  r_gear_type = RearGearType.create(name: gear[:name], count: gear[:count], internal: gear[:internal], standard: gear[:standard])
  r_gear_type.save
end
