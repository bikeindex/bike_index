class FrameMaterial
  include Enumable

  SLUGS = {
    magnesium: 5,
    organic: 4,
    composite: 3,
    titanium: 2,
    aluminum: 1,
    steel: 0
  }.freeze

  NAMES = {
    magnesium: "Magnesium",
    aluminum: "Aluminum",
    composite: "Carbon or composite",
    organic: "Wood or organic material",
    steel: "Steel",
    titanium: "Titanium"
  }.freeze

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  def name
    NAMES[slug]
  end

  attr_reader :slug, :id
end
