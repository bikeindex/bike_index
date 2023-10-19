class PropulsionType
  include Enumable

  SLUGS = {
    "foot-pedal": 0,
    "pedal-assist": 1,
    throttle: 2,
    "pedal-assist-and-throttle": 5,
    "hand-pedal": 3,
    "human-not-pedal": 4
  }.freeze

  NAMES = {
    "foot-pedal": "Foot Pedal",
    "pedal-assist": "Pedal Assist",
    throttle: "Electric Throttle",
    "pedal-assist-and-throttle": "Pedal Assist and Throttle",
    "hand-pedal": "Hand Cycle (hand pedal)",
    "human-not-pedal": "Human powered (but not by pedals)"
  }.freeze

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  # propulsion type can by one of the slugs, or motorized
  def self.for_vehicle(cycle_type, propulsion_type = nil)
    cycle_type = cycle_type&.to_sym
    propulsion_type = propulsion_type&.to_sym
    if CycleType::NEVER_MOTORIZED.include?(cycle_type)
      default_non_motorized_type(cycle_type)
    elsif CycleType::ALWAYS_MOTORIZED.include?(cycle_type) || propulsion_type == :motorized
      default_motorized_type(cycle_type)
    elsif slugs_sym.include?(propulsion_type)
      propulsion_type
    else
      default_non_motorized_type(cycle_type)
    end
  end

  def self.default_non_motorized_type(cycle_type)
    CycleType::PEDALS.include?(cycle_type) ? :"foot-pedal" : :"human-not-pedal"
  end

  def self.default_motorized_type(cycle_type)
    CycleType::PEDALS.include?(cycle_type) ? :"pedal-assist" : :throttle
  end

  attr_reader :slug, :id
end
