class PropulsionType
  include Enumable

  SLUGS = {
    "foot-pedal": 0,
    "pedal-assist": 1,
    throttle: 2,
    "hand-pedal": 3,
    "propulsion-other": 4
  }.freeze

  NAMES = {
    "foot-pedal": "Foot pedal",
    "pedal-assist": "Pedal Assist",
    throttle: "Electric throttle",
    "hand-pedal": "Hand cycle (hand pedal)",
    "propulsion-other": "Other style"
  }.freeze

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  attr_reader :slug, :id
end
