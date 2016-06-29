class Color < ActiveRecord::Base
  include AutocompleteHashable
  def self.old_attr_accessible
    %w(name priority display).map(&:to_sym).freeze
  end
  validates_presence_of :name, :priority
  validates_uniqueness_of :name
  has_many :bikes
  has_many :paints

  default_scope { order(:name) }
  scope :commonness, -> { order('priority ASC, name ASC') }

  def self.fuzzy_name_find(n)
    n && where('lower(name) = ?', n.downcase.strip).first
  end

  def autocomplete_hash
    {
      id: id,
      text: name,
      category: 'colors',
      priority: 1000,
      data: {
        priority: 1000,
        display: display,
        search_id: "c_#{id}"
      }
    }.as_json
  end

  def update_display_format
    u = display.match(/\#[^(\'|\")]*/)
    update_attribute :display, (u.present? ? u[0] : nil)
  end
end
