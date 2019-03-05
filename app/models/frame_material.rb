class FrameMaterial
  ENUMS = { 
    organic: 4, 
    composite: 3, 
    titanium: 2, 
    aluminum: 1, 
    steel: 0 
  }.freeze

  NAMES = {
    aluminum: "Aluminum",
    composite: "Carbon or composite", 
    organic: "Wood or organic material",
    steel: "Steel",
    titanium: "Titanium"
  }.freeze

  def self.select_options
    Array(NAMES.invert)
  end

  # For legacy api endpoints
  def self.legacy_selections
    NAMES.map{ |k,v| { slug: k.to_s, name: v } }
  end

  def initialize(enum)
    @enum = enum&.to_sym
  end

  def name
    NAMES[enum]
  end

  protected
  attr_reader :enum
end