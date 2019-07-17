class Color < ActiveRecord::Base
  include AutocompleteHashable
  include FriendlyNameFindable
  validates_presence_of :name, :priority
  validates_uniqueness_of :name
  has_many :bikes
  has_many :paints

  default_scope { order(:name) }
  scope :commonness, -> { order("priority ASC, name ASC") }

  def self.black
    where(name: "Black", priority: 1, display: "#000").first_or_create
  end

  def self.name_translation(name, locale: nil)
    I18n.t(
      name.to_s.downcase.gsub(/[^[:alnum:]]+/, "_"),
      scope: [:activerecord, :select_options, self.name.underscore],
      locale: locale,
    )
  end

  def self.select_options(locale: nil)
    pluck(:id, :name)
      .map { |id, name| [name_translation(name, locale: locale), id] }
  end

  def autocomplete_hash
    {
      id: id,
      text: name,
      category: "colors",
      priority: 1000,
      data: {
        priority: 1000,
        display: display,
        search_id: search_id,
      },
    }.as_json
  end

  def search_id
    "c_#{id}"
  end

  def update_display_format
    u = display.match(/\#[^(\'|\")]*/)
    update_attribute :display, (u.present? ? u[0] : nil)
  end
end
