class Color < ActiveRecord::Base
  attr_accessible :name, :priority, :display
  validates_presence_of :name, :priority
  validates_uniqueness_of :name
  has_many :bikes
  has_many :paints

  default_scope { order(:name) }
  scope :commonness, -> { order("priority ASC, name ASC") }

  def self.fuzzy_name_find(n)
    if !n.blank?
      self.find(:first, conditions: [ "lower(name) = ?", n.downcase.strip ])
    else
      nil
    end
  end

  def autocomplete_hash
    {
      id: id,
      text: name,
      category: 'colors',
      priority: 1000,
      data: {
        priority: 1000,
        display: "#{display} <span class='sch_c'>#{name}</span>"
      }
    }.as_json
  end

end
