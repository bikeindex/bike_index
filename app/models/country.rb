# == Schema Information
#
# Table name: countries
#
#  id         :integer          not null, primary key
#  iso        :string(255)
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Country < ApplicationRecord
  validates_presence_of :name
  validates_uniqueness_of :name, :iso

  has_many :stolen_records
  has_many :locations

  def self.select_options
    pluck(:id, :iso).map do |id, iso|
      [I18n.t(iso, scope: :countries), id]
    end
  end

  def self.friendly_find(name_or_iso)
    name_or_iso = name_or_iso.to_s.strip.downcase
    return if name_or_iso.blank?
    return united_states if name_or_iso.in? %w[us usa]

    find_by("lower(name) = ? or lower(iso) = ?", name_or_iso, name_or_iso)
  end

  def self.united_states
    where(name: "United States", iso: "US").first_or_create
  end

  def self.canada
    where(name: "Canada", iso: "CA").first_or_create
  end

  def self.netherlands
    where(name: "Netherlands", iso: "NL").first_or_create
  end

  def self.valid_names
    StatesAndCountries.countries.map { |c| c[:name] }
  end

  def united_states?
    iso.upcase == "US"
  end

  def default?
    united_states?
  end

  # consistency with state
  def abbreviation
    iso
  end
end
