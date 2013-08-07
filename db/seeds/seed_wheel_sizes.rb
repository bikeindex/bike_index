# Seed the database with the wheel sizes
wheel_sizes = [
  {name: '28 x 1 1/2, 700 B [635]', iso_bsd: 635, wheel_size_set: 'Rare wheel sizes ', description: '[635] 28 x 1 1/2, 700 B (Rare)'},
  {name: '27in', iso_bsd: 630, wheel_size_set: 'Standard wheel size ', description: '[630] 27in (Standard size)'},
  {name: '700 C', iso_bsd: 622, wheel_size_set: 'Standard wheel size ', description: '[622] 700 C, 29in mountain bikes (Standard size)'},
  {name: '26 x 1.25, x 1.375 [599]', iso_bsd: 599, wheel_size_set: 'Rare wheel sizes', description: '[599] 26 x 1.25, x 1.375 (Rare)'},
  {name: '26 x 1 3/8 [597]', iso_bsd: 597, wheel_size_set: 'Common wheel sizes ', description: '[597] 26 x 1 3/8 (Older Schwinns, S-6) (Common)'},
  {name: '26 x 1 3/8 [590]', iso_bsd: 590, wheel_size_set: 'Less common wheel sizes ', description: '[590] 26 x 1 3/8 English 3-speeds, older department-store 10 speeds (Uncommon)'},
  {name: '700 D [587]', iso_bsd: 587, wheel_size_set: 'Rare wheel sizes ', description: '[587] 700 D GT size (Rare)'},
  {name: '650B', iso_bsd: 584, wheel_size_set: 'Common wheel sizes ', description: '[584] 650B, 26 x 1 1/2 (Common)'},
  {name: '26 x 1 3/4, 26 x 1 or 650 C [571]', iso_bsd: 571, wheel_size_set: 'Less common wheel sizes ', description: '[571] 26 x 1 3/4 (schwinn), 26 x 1, 650 C (Uncommon)'},
  {name: '26in', iso_bsd: 559, wheel_size_set: 'Standard wheel size ', description: '[559] 26in (Standard size)'},
  {name: '24 x 1 1/4, 24 x 1 3/8 (S-5) [547]', iso_bsd: 547, wheel_size_set: 'Rare wheel sizes ', description: '[547] 24 x 1 1/4, 24 x 1 3/8 (S-5) [547]'},
  {name: '24 x 1 1/8, 24 x 1 3/8 (E.5), 600 A [540]', iso_bsd: 540, wheel_size_set: 'Rare wheel sizes ', description: '[540] 24 x 1 1/8, 24 x 1 3/8 (E.5), 600 A (Rare)'},
  {name: '24 x 1 performance wheels for smaller riders [520]', iso_bsd: 520, wheel_size_set: 'Less common wheel sizes ', description: '[520] 24 x 1 performance wheels for smaller riders (Uncommon)'},
  {name: '24in [507]', iso_bsd: 507, wheel_size_set: 'Standard wheel size ', description: '[507] 24in (Standard size)'},
  {name: '550 A [490]', iso_bsd: 490, wheel_size_set: 'Rare wheel sizes ', description: '[490] 550 A (Rare)'},
  {name: '22 x 1.75; x 2.125 [457]', iso_bsd: 457, wheel_size_set: 'Rare wheel sizes ', description: '[457] 22 x 1.75; x 2.125 (Rare)'},
  {name: '20 x 1 1/8; x 1 1/4; x 1 3/8 [451]', iso_bsd: 451, wheel_size_set: 'Less common wheel sizes ', description: '[451] 20 x 1 1/8; x 1 1/4; x 1 3/8 (Uncommon)'},
  {name: '500 A [440]', iso_bsd: 440, wheel_size_set: 'Rare wheel sizes ', description: '[440] 500 A (Rare)'},
  {name: '20 x 1 3/4 [419]', iso_bsd: 419, wheel_size_set: 'Rare wheel sizes ', description: '[419] 20 x 1 3/4 (Rare)'},
  {name: '20in', iso_bsd: 406, wheel_size_set: 'Standard wheel size ', description: '[406] 20in (Standard size)'},
  {name: '450 A [390]', iso_bsd: 390, wheel_size_set: 'Rare wheel sizes ', description: '[390] 450 A (Rare)'},
  {name: '17 x 1 1/4 [369]', iso_bsd: 369, wheel_size_set: 'Rare wheel sizes ', description: '[369] 17 x 1 1/4 (Rare)'},
  {name: '18in', iso_bsd: 355, wheel_size_set: 'Standard wheel size ', description: '[355] 18in (Standard size)'},
  {name: '16 x 1 3/8 [349]', iso_bsd: 349, wheel_size_set: 'Rare wheel sizes ', description: '[349] 16 x 1 3/8 (Rare)'},
  {name: '400 A [340]', iso_bsd: 340, wheel_size_set: 'Rare wheel sizes ', description: '[340] 400 A (Rare)'},
  {name: '16 x 1 3/8 [337]', iso_bsd: 337, wheel_size_set: 'Rare wheel sizes ', description: '[337] 16 x 1 3/8 (Rare)'},
  {name: '16 x 1 3/4 [317]', iso_bsd: 317, wheel_size_set: 'Rare wheel sizes ', description: '[317] 16 x 1 3/4 (Rare)'},
  {name: '16in', iso_bsd: 305, wheel_size_set: 'Standard wheel size ', description: '[305] 16in (Standard size)'},
  {name: '12in', iso_bsd: 203, wheel_size_set: 'Standard wheel size ', description: '[23] 12in (Standard size)'},
  {name: '10 x 2 [152]', iso_bsd: 152, wheel_size_set: 'Rare wheel sizes ', description: '[152] 10 x 2 (Rare)'},
  {name: '8 x 1 1/4 [137]', iso_bsd: 137, wheel_size_set: 'Rare wheel sizes ', description: '[137] 8 x 1 1/4 (Rare)'},
  {name: 'Other style', iso_bsd: 0, wheel_size_set: 'Rare wheel sizes ', description: 'Other style'}
]
wheel_sizes.each do |wheel_size|
  wheel_size = WheelSize.create(name: wheel_size[:name], wheel_size_set: wheel_size[:wheel_size_set], description: wheel_size[:description], iso_bsd: wheel_size[:iso_bsd])
  wheel_size.save
end