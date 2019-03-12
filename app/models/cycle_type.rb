class CycleType
  include Enumable

  SLUGS = %i[
    bike
    tandem
    unicycle
    tricycle
    stroller
    recumbent
    trailer
    wheelchair
    cargo
    tall-bike
    penny-farthing
    cargo-rear
    cargo-trike
    cargo-trike-rear
    trail-behind
    pedi-cab
  ].freeze

  NAMES = {
    bike: "Bike",
    tandem: "Tandem", 
    unicycle: "Unicycle",
    tricycle: "Tricycle",
    stroller: "Stroller",
    recumbent: "Recumbent",
    trailer: "Bike Trailer",
    wheelchair: "Wheelchair",
    cargo: "Cargo Bike (front storage)",
    "tall-bike": "Tall Bike",
    "penny-farthing": "Penny Farthing",
    "cargo-rear": "Cargo Bike (rear storage)",
    "cargo-trike": "Cargo Tricycle (front storage)", 
    "cargo-trike-rear": "Cargo Tricycle (rear storage)",
    "trail-behind": "Trail behind (half bike)",
    "pedi-cab": "Pedi Cab (rickshaw)"
  }.freeze

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  attr_reader :slug, :id
end
