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
    "human-not-pedal": "Human powered (not by pedals)"
  }.freeze

  MOTORIZED = %i[pedal-assist throttle pedal-assist-and-throttle].freeze
  PEDAL = %i[foot-pedal hand-pedal pedal-assist pedal-assist-and-throttle].freeze

  class << self
    def motorized?(slug)
      MOTORIZED.include?(slug&.to_sym)
    end

    def not_motorized?(slug)
      not_motorized.include?(slug&.to_sym)
    end

    def pedal_type?(slug_sym)
      PEDAL.include?(slug_sym)
    end

    # propulsion type can by one of the slugs or :motorized
    def for_vehicle(cycle_type, propulsion_type = nil)
      cycle_type = cycle_type&.to_sym
      propulsion_type = propulsion_type&.to_sym
      propulsion_type = default_motorized_type(cycle_type) if propulsion_type == :motorized
      propulsion_type = find_sym(propulsion_type) unless slugs_sym.include?(propulsion_type)
      v_types = valid_propulsion_types_for(cycle_type)

      return propulsion_type if v_types.include?(propulsion_type)

      # If a motorized type was passed, try to return a motorized type
      propulsion_type = default_motorized_type(cycle_type) if motorized?(propulsion_type)
      return propulsion_type if v_types.include?(propulsion_type)

      valid_propulsion_types_for(cycle_type).first
    end

    private

    def not_motorized
      (slugs_sym - MOTORIZED).freeze
    end

    def not_pedal
      (slugs_sym - PEDAL).freeze
    end

    def default_non_motorized_type(cycle_type)
      return nil if CycleType.strict_motorized(cycle_type) == :always
      CycleType.pedal_type?(cycle_type) ? :"foot-pedal" : :"human-not-pedal"
    end

    def default_motorized_type(cycle_type)
      return nil if CycleType.strict_motorized(cycle_type) == :never
      CycleType.pedal_type?(cycle_type) ? :"pedal-assist" : :throttle
    end

    def valid_propulsion_types_for(cycle_type)
      valid_types = if CycleType.pedal_type?(cycle_type)
        slugs_sym
      else
        not_pedal.reverse
      end

      strictly = CycleType.strict_motorized(cycle_type)
      if strictly == :never
        valid_types -= MOTORIZED
      elsif strictly == :always
        valid_types -= not_motorized
      end
      valid_types
    end
  end

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  attr_reader :slug, :id

  def motorized?
    self.class.motorized?(slug)
  end

  def human_powered?
    !motorized?
  end
end
