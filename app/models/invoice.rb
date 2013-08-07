class Invoice < ActiveRecord::Base
  attr_accessible :amount_in_cents,
    :billing_period_start,
    :billing_period_end,
    :paid_at,
    :organization_id,
    :bike_count,
    :bike_with_photo_count

  # TODO: Either think of a clever way of incorporating bike_with_photo count into billing or remove it

  acts_as_paranoid

  has_many :bikes

  belongs_to :organization

  validates_presence_of :billing_period_start, :billing_period_end, :organization_id
  validates_uniqueness_of :billing_period_start, scope: :organization_id

  def amount_in_dollars
    self.amount_in_cents/100
  end
  

end
