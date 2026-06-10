# Bump well-known frame makers to max priority so seeded bikes favor them
# (see SeedHelpers.weighted_frame_maker_id). update_column skips the save
# callback that would recalculate priority from bike/component counts.
priority_manufacturer_names = [
  "Aventón", "Bianchi", "Bridgestone", "Brompton Bicycle", "Cannondale",
  "Canyon bicycles", "Cervélo", "Colnago", "Diamondback", "Electra", "Evil",
  "Felt", "Fit bike Co.", "Focus", "Fuji", "Gary Fisher", "Giant (and LIV)",
  "GT Bicycles", "Handsome Cycles", "Haro", "Ibis", "Intense",
  "Ironhorse Bicycles (Iron Horse Bikes)", "IZIP", "Jamis", "Jetson",
  "Juliana Bicycles", "KHS Bicycles", "Kink", "Kona", "Marin Bikes", "Mongoose",
  "Moots Cycles", "Motobecane", "Niner", "Nishiki", "Norco Bikes", "Orbea",
  "Pinarello", "Pivot", "Pure Cycles (Pure Fix Cycles)", "Rad Power Bikes",
  "Raleigh", "Redline", "Retrospec", "Ridley",
  "Riese & Müller (Riese and Muller)", "Roadmaster", "Rocky Mountain Bicycles",
  "Salsa", "Santa Cruz", "Schwinn", "SCOTT", "SE Bikes", "Soma", "Specialized",
  "Strider (Strider sports)", "Sunday", "Super73", "Supercycle", "Surly", "Tern",
  "Transition Bikes", "Trek", "Univega", "Urban Arrow", "Velotric", "Woom",
  "Yamaha", "Yeti", "Yuba"
]

missing = priority_manufacturer_names.reject do |name|
  Manufacturer.friendly_find(name)&.update_column(:priority, 100)
end
raise "Priority manufacturers not found: #{missing.join(", ")}" if missing.any?

puts "Set priority 100 on #{priority_manufacturer_names.length} manufacturers"
