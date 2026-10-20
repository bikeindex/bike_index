class HandlebarType
  include Enumable

  SLUGS = {
    horizontal: 0,
    drop_bar: 5,
    forward: 4,
    rearward: 3,
    other: 2
  }.freeze

  NAMES = {
    horizontal: "Flat or riser (horizontal facing)",
    drop_bar: "Drop bars",
    forward: "Forward facing",
    rearward: "Rear facing",
    other: "Not handlebars"
  }.freeze

  attr_reader :slug, :id

  # API clients still send the former slugs
  def self.find_sym(str)
    str.to_s.strip.match?(/\A(flat|riser|bmx( style)?)\z/i) ? :horizontal : super
  end

  # The API still emits horizontal's slug from before the rename
  def self.api_slug(slug) = (slug.to_s == "horizontal") ? "flat" : slug

  def self.legacy_selections = super.map { it.merge(slug: api_slug(it[:slug])) }

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end
end
