# == Schema Information
#
# Table name: lock_types
# Database name: primary
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  slug       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class LockType < ApplicationRecord
  include FriendlySlugFindable
end
