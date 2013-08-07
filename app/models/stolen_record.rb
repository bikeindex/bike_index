class StolenRecord < ActiveRecord::Base
  attr_accessible :police_report_filed,
    :date_stolen,
    :bike,
    :police_report_information,
    :street,
    :zipcode,
    :city,
    :state,
    :latitude,
    :longitude,
    :location_id,
    :locking_description_id,
    :theft_description,
    :current,
    :phone,
    :phone_for_everyone,
    :phone_for_users,
    :phone_for_shops,
    :phone_for_police

  belongs_to :bike

  validates_presence_of :bike, :date_stolen

  default_scope where(current: true)

  def address
    [street, city, state, zipcode, "United States"].compact.join(', ')
  end

  unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode, :if => lambda { self.city.present? && self.zipcode.present? && self.city.present? }
  end

  before_save :set_phone
  def set_phone
    self.phone = Phonifyer.phonify(self.phone) if self.phone 
  end


end
