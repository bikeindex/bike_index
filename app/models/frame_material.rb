class FrameMaterial
  SLUGS = {
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

  def self.slugs; SLUGS.keys.map(&:to_s) end

  def self.select_options
    Array(NAMES.invert)
  end

  # For legacy api endpoints
  def self.legacy_selections
    NAMES.map { |k, v| { slug: k.to_s, name: v } }
  end

  def self.friendly_find(str)
    return nil unless str.present?
    str = str.downcase.strip
    slug = (slugs & [str]).first
    slug ||= NAMES.detect do |k, v|
      ([k.to_s, v.downcase] + v.downcase.strip.split(" or ")).include?(str)
    end&.first
    new(slug.to_sym) if slug.present?
  end

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  def name
    NAMES[slug]
  end

  protected

  attr_reader :slug, :id
end
