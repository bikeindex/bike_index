class Country < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name, :iso

  has_many :stolen_records
  has_many :locations

  def self.select_options
    pluck(:id, :iso).map do |id, iso|
      [I18n.t(iso, scope: :countries), id]
    end
  end

  def self.fuzzy_find(str)
    return nil unless str.present?
    fuzzy_iso_find(str) || where("lower(name) = ?", str.downcase.strip).first
  end

  def self.fuzzy_iso_find(str)
    str = "us" if str.match(/usa/i)
    str && where("lower(iso) = ?", str.downcase.strip).first
  end

  def self.united_states
    where(name: "United States", iso: "US").first_or_create
  end

  def self.netherlands
    where(name: "Netherlands", iso: "NL").first_or_create
  end

  def self.valid_names
    StatesAndCountries.countries.map { |c| c[:name] }
  end
end
