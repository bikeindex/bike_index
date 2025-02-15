class Currency
  include Enumable

  SLUGS = {
    usd: 0,
    cad: 1,
    eur: 2
  }.freeze

  NAMES = {
    usd: "USD",
    cad: "CAD",
    eur: "EUR"
  }.freeze

  SYMBOLS = {
    usd: "$",
    cad: "$",
    eur: "€"
  }.freeze

  def self.default
    new(:usd)
  end

  def self.find_sym(str)
    super || self::SYMBOLS.detect { |k, v| str == v }&.first
  end

  def initialize(slug)
    @slug = self.class.find_sym(slug)
    @id = SLUGS[@slug]
    @symbol = SYMBOLS[@slug]
  end

  attr_reader :slug, :id, :symbol
end
