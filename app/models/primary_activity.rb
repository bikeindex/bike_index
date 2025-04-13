# == Schema Information
#
# Table name: primary_activities
#
#  id                         :bigint           not null, primary key
#  is_family                  :boolean
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
  belongs_to :primary_activity_family

end
