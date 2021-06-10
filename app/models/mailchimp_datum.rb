class MailchimpDatum < ApplicationRecord
  STATUS_ENUM = {
    subscribed: 0,
    unsubscribed: 1, # Should remove
    pending: 2, # Never should be in this status
    cleaned: 3
  }

  validates_presence_of :email
  validates_un

  enum status: STATUS_ENUM

  before_validation :set_calculated_attributes


  def set_calculated_attributes
    self.
    self.data = calculated_data
  end

  def calculated_data
    {

    }
  end
end
