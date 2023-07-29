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
