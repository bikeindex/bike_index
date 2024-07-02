# == Schema Information
#
# Table name: ads
#
#  id              :integer          not null, primary key
#  body            :text
#  image           :string(255)
#  live            :boolean          default(FALSE), not null
#  target_url      :text
#  title           :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#
class Ad < ApplicationRecord
  belongs_to :organization
  validates_presence_of :title
  validates_uniqueness_of :title

  mount_uploader :image, PartnerUploader

  scope :live, -> { where(live: true) }
end
