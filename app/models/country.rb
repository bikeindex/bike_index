class Country < ActiveRecord::Base
  def self.old_attr_accessible
    %w(name iso).map(&:to_sym).freeze
  end
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :iso
  has_many :stolen_records
  has_many :locations

  def self.fuzzy_iso_find(n)
    n = 'us' if n.match(/usa/i)
    n && where('lower(iso) = ?', n.downcase.strip).first
  end


  def self.united_states
    where(name: 'United States', iso: 'US').first_or_create
  end

end
