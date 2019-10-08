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

  def self.fuzzy_find(name_or_iso)
    name_or_iso = name_or_iso.to_s.strip.downcase
    name_or_iso = "us" if name_or_iso == "usa"
    return if name_or_iso.blank?

    find_by("lower(name) = ? or lower(iso) = ?", name_or_iso, name_or_iso)
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
