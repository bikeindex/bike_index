class Location < ActiveRecord::Base
  attr_accessible :name,
    :organization_id,
    :organization,
    :zipcode,
    :city,
    :state,
    :street,
    :phone,
    :email,
    :latitude,
    :longitude


  acts_as_paranoid
  belongs_to :organization
  validates_presence_of :name, :organization_id, :zipcode, :city, :state, :street
  has_many :bikes

  def address
    [street, city, state, zipcode, "United States"].compact.join(', ')
  end

  unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode
  end

  before_save :set_phone
  def set_phone
    if self.phone 
      self.phone = Phonifyer.phonify(self.phone)
    end
  end

  def org_location_id
    "#{self.organization_id}_#{self.id}"
  end

end
