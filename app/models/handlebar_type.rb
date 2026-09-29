class HandlebarType
  include Enumable

  SLUGS = {
    drop_bar: 5,
    forward: 4,
    rearward: 3,
    other: 2,
    flat: 0
  }.freeze

  NAMES = {
    drop_bar: "Drop bars",
    forward: "Forward facing",
    rearward: "Rear facing",
    other: "Not handlebars",
    flat: "Flat or riser (horizontal facing)"
  }.freeze

  attr_reader :slug, :id

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end
end
