class Currency
  include Enumable

  SLUGS = {
    usd: 0,
    cad: 1,
    eur: 2,
    mxn: 3
  }.freeze

  NAMES = {
    usd: "USD",
    cad: "CAD",
    eur: "EUR",
    mxn: "MXN"
  }.freeze

  SYMBOLS = {
    usd: "$",
    cad: "$",
    eur: "€",
    mxn: "$"
  }.freeze

  def self.default
    new(:usd)
  end

  def self.find_sym(str)
    super || self::SYMBOLS.detect { |k, v| str == v }&.first
  end

  def self.select_options
    slugs.map { |slug| ["#{SYMBOLS[slug.to_sym]} (#{slug_translation(slug)})", slug] }
  end

  def initialize(slug)
    @slug = self.class.find_sym(slug)
    @id = SLUGS[@slug]
    @symbol = SYMBOLS[@slug]
  end

  attr_reader :slug, :id, :symbol
end
