class Ctype < ActiveRecord::Base
  # Note: Ctype is short for component_type.
  # The name had to be shortened because of join table key length
  include FriendlySlugFindable

  attr_accessor :cgroup_name

  belongs_to :cgroup

  mount_uploader :image, AvatarUploader

  has_many :components

  def self.select_options
    normalize = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]+/, "_") }
    translation_scope = [:activerecord, :select_options, self.name.underscore]

    pluck(:id, :name).map do |id, name|
      localized_name = I18n.t(normalize.call(name), scope: translation_scope)
      [localized_name, id]
    end
  end

  def self.other
    where(name: "unknown", has_multiple: false, cgroup_id: Cgroup.additional_parts.id).first_or_create
  end

  before_create :set_calculated_attributes

  def set_calculated_attributes
    return true unless self.cgroup_name.present?
    self.cgroup_id = Cgroup.friendly_find(cgroup_name)&.id
  end
end
