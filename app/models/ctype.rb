# == Schema Information
#
# Table name: ctypes
#
#  id             :integer          not null, primary key
#  has_multiple   :boolean          default(FALSE), not null
#  image          :string(255)
#  name           :string(255)
#  secondary_name :string(255)
#  slug           :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cgroup_id      :integer
#
class Ctype < ApplicationRecord
  # Note: Ctype is short for component_type.
  # The name had to be shortened because of join table key length
  include FriendlySlugFindable

  MEMOIZE_OTHER = ENV["SKIP_MEMOIZE_STATIC_MODEL_RECORDS"].blank? # enable skipping for testing

  belongs_to :cgroup

  has_many :components

  mount_uploader :image, AvatarUploader

  attr_accessor :cgroup_name, :image_cache

  def self.select_options
    normalize = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]+/, "_") }
    translation_scope = [:activerecord, :select_options, name.underscore]

    pluck(:id, :name).map do |id, name|
      localized_name = I18n.t(normalize.call(name), scope: translation_scope)
      [localized_name, id]
    end
  end

  def self.other
    return @other if MEMOIZE_OTHER && defined?(@other)

    @other = where(name: "unknown", has_multiple: false, cgroup_id: Cgroup.additional_parts.id).first_or_create
  end

  before_create :set_calculated_attributes

  def set_calculated_attributes
    return true unless cgroup_name.present?

    self.cgroup_id = Cgroup.friendly_find(cgroup_name)&.id
  end
end
