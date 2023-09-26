class PropulsionType
  include Enumable

  SLUGS = {
    "foot-pedal": 0,
    "pedal-assist": 1,
    throttle: 2,
    "pedal-assist-and-throttle": 5,
    "hand-pedal": 3,
    "propulsion-other": 4
  }.freeze

  NAMES = {
    "foot-pedal": "Foot Pedal",
    "pedal-assist": "Pedal Assist",
    throttle: "Electric Throttle",
    "pedal-assist-and-throttle": "Pedal Assist and Throttle",
    "hand-pedal": "Hand Cycle (hand pedal)",
    "propulsion-other": "Other Style"
  }.freeze

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  attr_reader :slug, :id
end
