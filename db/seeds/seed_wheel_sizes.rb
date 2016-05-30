# Seed the database with the wheel sizes
wheel_sizes = [
  { name: '8 x 1 1/4', iso_bsd: 137, priority: 4, description: '8 x 1 1/4 (Rare)' },
  { name: '10 x 2', iso_bsd: 152, priority: 4, description: '10 x 2 (Rare)' },
  { name: '12in', iso_bsd: 203, priority: 1, description: '12in (Standard size)' },
  { name: '16in', iso_bsd: 305, priority: 1, description: '16in (Standard size)' },
  { name: '16 x 1 3/4', iso_bsd: 317, priority: 4, description: '16 x 1 3/4 (Rare)' },
  { name: '16 x 1 3/8', iso_bsd: 335, priority: 4, description: '16 x 1 3/8 Polish juvenile (Rare)' },
  { name: '16 x 1 3/8', iso_bsd: 337, priority: 4, description: '16 x 1 3/8 Folders and recumbents (Rare)' },
  { name: '400 A', iso_bsd: 340, priority: 4, description: '400 A (Rare)' },
  { name: '16 x 1 3/8', iso_bsd: 349, priority: 4, description: '16 x 1 3/8, mysterious (Rare)' },
  { name: '18in', iso_bsd: 355, priority: 1, description: '18in (Standard size)' },
  { name: '17 x 1 1/4', iso_bsd: 369, priority: 4, description: '17 x 1 1/4 (Rare)' },
  { name: '450 A', iso_bsd: 390, priority: 4, description: '450 A (Rare)' },
  { name: '20in', iso_bsd: 406, priority: 1, description: '20in (Standard size)' },
  { name: '20 x 1 3/4', iso_bsd: 419, priority: 4, description: '20 x 1 3/4 (Rare)' },
  { name: '500 A', iso_bsd: 440, priority: 4, description: '500 A (Rare)' },
  { name: '20 x 1 1/8; x 1 1/4; x 1 3/8', iso_bsd: 451, priority: 3, description: '20 x 1 1/8; x 1 1/4; x 1 3/8 (Uncommon)' },
  { name: '22 x 1.75; x 2.125', iso_bsd: 457, priority: 4, description: '22 x 1.75; x 2.125 (Rare)' },
  { name: '550 A', iso_bsd: 490, priority: 4, description: '550 A (Rare)' },
  { name: '24in', iso_bsd: 507, priority: 1, description: '24in (Standard size)' },
  { name: '24 x 1', iso_bsd: 520, priority: 3, description: '24 x 1 performance wheels for smaller riders (Uncommon)' },
  { name: '24 x 1 1/8, 24 x 1 3/8 (E.5), 600 A', iso_bsd: 540, priority: 4, description: '24 x 1 1/8, 24 x 1 3/8 (E.5), 600 A (Rare)' },
  { name: '24 x 1 1/4, 24 x 1 3/8 (S-5)', iso_bsd: 547, priority: 4, description: '24 x 1 1/4, 24 x 1 3/8, Schwinn Juvenile (Rare)' },
  { name: '26in', iso_bsd: 559, priority: 1, description: '26in (Standard size)' },
  { name: '650 C', iso_bsd: 571, priority: 3, description: 'Schwinn Cruisers, Tri- and Time-trial bikes (uncommon)' },
  { name: '650 B', iso_bsd: 584, priority: 1, description: '27.5 mountain bikes, smaller road bikes (Standard size)' },  
  { name: '700 D', iso_bsd: 587, priority: 4, description: '700 D GT size (Rare)' },
  { name: '26 x 1 3/8', iso_bsd: 590, priority: 3, description: '26 x 1 3/8 English 3-speeds, older department-store 10 speeds (Uncommon)' },
  { name: '26 x 1 3/8', iso_bsd: 597, priority: 2, description: '26 x 1 3/8 (Older Schwinns, S-6) (Common)' },
  { name: '26 x 1.25, x 1.375', iso_bsd: 599, priority: 4, description: '26 x 1.25, x 1.375 (Rare)' },
  { name: '700 C', iso_bsd: 622, priority: 1, description: '700 C, 29in mountain bikes (Standard size)' },
  { name: '27in', iso_bsd: 630, priority: 1, description: '27in (Standard size)' },
  { name: '28 x 1 1/2, 700 B', iso_bsd: 635, priority: 4, description: '28 x 1 1/2, 700 B (Rare)' },
  { name: '32in', iso_bsd: 686, priority: 4, description: '32in, Unicycle size (Rare)' }
  { name: '36in', iso_bsd: 787, priority: 4, description: '36in, Unicycle size (Rare)' }
]
wheel_sizes.each do |wheel_size|
  wheel_size = WheelSize.create!(name: wheel_size[:name], priority: wheel_size[:priority], description: wheel_size[:description], iso_bsd: wheel_size[:iso_bsd])
  wheel_size.save
end
