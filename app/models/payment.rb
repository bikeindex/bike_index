class Payment < ActiveRecord::Base
  attr_accessible :user_id,
    :is_current,
    :is_recurring,
    :stripe_id,
    :last_payment_date,
    :first_payment_date,
    :amount

  belongs_to :user
  validates_presence_of :user_id

  scope :current, where(is_current: true)
  scope :subscription, where(is_recurring: true)
  

  # before_create :mark_subscribed 
  # def mark_subscribed 
  #   if user.present?
  #     user.update_attribute :is_subscribed, true 
  #   end
  #   true
  # end

  # def mark_closed(time) 
  #   return true unless is_current
  #   self.is_current = false 
  #   self.end_date = time
  #   user.update_attribute :is_subscribed, false
  #   save
  # end

end
