# == Schema Information
#
# Table name: locks
# Database name: primary
#
#  id                 :integer          not null, primary key
#  combination        :string(255)
#  has_combination    :boolean
#  has_key            :boolean          default(TRUE)
#  key_serial         :string(255)
#  lock_model         :string(255)
#  manufacturer_other :string(255)
#  notes              :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  lock_type_id       :integer          default(1)
#  manufacturer_id    :integer
#  user_id            :integer
#
# Indexes
#
#  index_locks_on_user_id  (user_id)
#
class Lock < ApplicationRecord
  belongs_to :manufacturer
  belongs_to :lock_type
  belongs_to :user

  validates_presence_of :user, on: :create
  validates_presence_of :manufacturer
  validates_presence_of :lock_type

  def mnfg_name
    Manufacturer.calculated_mnfg_name(manufacturer, manufacturer_other) ||
      "Other" # Weird legacy behavior, shrug
  end
end
