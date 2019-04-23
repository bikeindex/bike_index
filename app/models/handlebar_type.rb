class HandlebarType
  include Enumable

  SLUGS = {
    drop: 5,
    forward: 4,
    rearward: 3,
    other: 2,
    bmx: 1,
    flat: 0,
  }.freeze

  NAMES = {
    drop: "Drop",
    forward: "Forward facing",
    rearward: "Rear facing",
    other: "Not handlebars",
    bmx: "BMX style",
    flat: "Flat or riser",
  }.freeze

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  attr_reader :slug, :id
end
