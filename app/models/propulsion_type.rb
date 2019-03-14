class PropulsionType
  include Enumable

  SLUGS = {
    "foot-pedal": 0,
    "hand-pedal": 1,
    sail: 2,
    insufflation: 3,
    "electric-assist": 4,
    "electric-throttle": 5,
    gas: 6,
    "other-style": 7
  }.freeze

  NAMES = {
    "foot-pedal": "Foot pedal",
    "hand-pedal": "Hand pedal",
    sail: "Sail",
    insufflation: "Insufflation",
    "electric-assist": "Electric Assist",
    "electric-throttle": "Electric throttle",
    gas: "Gas",
    "other-style": "Other style"
  }.freeze

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  attr_reader :slug, :id
end
