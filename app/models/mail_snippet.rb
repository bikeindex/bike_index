class MailSnippet < ActiveRecord::Base
  attr_accessible :name,
    :body,
    :is_enabled,
    :is_location_triggered,
    :address,
    :proximity_radius

  validates_presence_of :name

  scope :enabled, -> { where(is_enabled: true) }

  # unless Rails.env.test?
    geocoded_by :address
    after_validation :geocode, if: lambda { address.present? }
  # end

  def self.matching_opts(opts)
    return nil unless opts[:mailer_method].match("ownership_invitation_email")
    bike = opts[:bike]
    return nil unless bike.stolen && bike.current_stolenRecord.present?
    stolenRecord = bike.current_stolenRecord
    return nil unless stolenRecord.latitude.present? && stolenRecord.longitude.present?
    match = nil
    self.enabled.where(is_location_triggered: true).each do |snippet|

      distance = snippet.distance_to(stolenRecord)
      match = snippet if distance <= snippet.proximity_radius
    end
    match
  end




end
