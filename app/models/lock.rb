class Lock < ApplicationRecord
  belongs_to :manufacturer
  belongs_to :lock_type
  belongs_to :user

  validates_presence_of :user, on: :create
  validates_presence_of :manufacturer
  validates_presence_of :lock_type

  def manufacturer_name
    if manufacturer.name == "Other" && manufacturer_other.present?
      manufacturer_other
    else
      manufacturer.name
    end
  end
end
