# == Schema Information
#
# Table name: primary_activities
#
#  id                         :bigint           not null, primary key
#  family                     :boolean
#  name                       :string
#  slug                       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  primary_activity_family_id :bigint
#
# Indexes
#
#  index_primary_activities_on_primary_activity_family_id  (primary_activity_family_id)
#
class PrimaryActivity < ApplicationRecord
  include FriendlySlugFindable

  belongs_to :primary_activity_family, class_name: "PrimaryActivity"

  has_many :primary_activity_flavors, class_name: "PrimaryActivity",
    foreign_key: :primary_notification_id
  has_many :bikes
  has_many :bike_versions

  def flavor?
    !family?
  end
end
