/ # :as => :grouped_select, :group_method => :wheel_group, :priority => ['01'],

##Bikes
  t.string :name
  t.integer :owner_id
  t.integer :creator_id
  t.string :email
  t.string :transfer_hash
  avatar

---

##Bike ID
  t.integer :bike_id
  t.string :serial
  t.integer :manufacturer
    t.string :other_manufacturer
  t.integer :frame_manufacture_year

---

##Bike Description
##Required
  t.integer :handlebar_style
    t.integer :non_standard_bicycle
      t.string :other_non_standard_bicycle_type
  t.integer :rear_wheel_size
  t.boolean :rear_tire_width
  t.integer :primary_color
##Un-required
  t.integer :frame_material
    t.string :other_frame_material
  t.integer :rear_gears
  t.integer :front_gears
  t.string :secondary_color
  t.string :gender
  t.integer :type_of_brakes
  t.integer :propulsion
    t.string :other_propulsion
  t.integer :front_wheel_size
  t.boolean :front_tire_width
  t.boolean :tandem

---

##Frame Geometries
  t.integer :bike_id
  t.float :seat_tube
  t.float :top_tube
  t.float :dropout_to_dropout

---

##Bike Component Collections
  t.integer :bike_id
  t.string :drivechain
    t.string :shifters
    t.string :front_derailleur
    t.string :rear_derailleur
    t.string :chain
    t.string :cranks
    t.string :pedals
    t.string :rear_gears

  t.string :headset
  t.string :bottom_bracket

  t.string :wheels
    t.string :front_wheel
      t.string :front_hub
      t.string :front_rim
      t.string :front_spokes
      t.string :front_tire
    t.string :rear_wheel
      t.string :rear_hub
      t.string :rear_rim
      t.string :rear_spokes
      t.string :rear_tire


  t.string :accessories
    t.string :rack
    t.string :fenders
    t.string :lights
    t.string :bottle_cages
