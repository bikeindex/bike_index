# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  end_at     :datetime
#  kind       :integer
#  start_at   :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_memberships_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Membership < ApplicationRecord
  KIND_ENUM = {basic: 0, plus: 1, patron: 2}

  belongs_to :user

  enum :kind, KIND_ENUM
end
