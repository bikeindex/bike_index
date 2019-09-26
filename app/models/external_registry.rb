class ExternalRegistry < ActiveRecord::Base
  extend ExternalRegistries::ExternalRegistries

  validates :name, :url, :client_class, presence: true

  belongs_to :country
  has_many :external_registry_bikes, dependent: :destroy
  alias_method :bikes, :external_registry_bikes

  scope :in_country, ->(country_iso) { where(country: Country.fuzzy_iso_find(country_iso)) }

  def self.search_for_bikes_with(serial_number:)
    results = all
      .map { |registry| Thread.new { registry.search_registry(serial_number: serial_number) } }
      .map(&:value)
      .flatten
      .compact

    ExternalRegistryBike.where(id: results.map(&:id))
  end

  def search_registry(serial_number:)
    api_client.search(serial_number)
  end

  def api_client
    klass = ["ExternalRegistries", client_class].join("::").constantize
    klass.new
  end
end
