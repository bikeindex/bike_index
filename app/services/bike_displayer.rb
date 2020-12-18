# Contains methods used for display. Trying this out instead of decorators
# ... obviously, this adds one more place to look for methods on bikes, but whatever
class BikeDisplayer
  # Not sure if I like everything being class methods, but doing that for now anyway
  class << self
    def display_contact_owner?(bike, user = nil)
      bike.stolen? && bike.current_stolen_record.present?
    end

    def display_impound_claim?(bike, user = nil)
      return true if bike.current_impound_record.present?
      return false if user.blank?
      bike.impound_claims_submitting.where(user_id: user.id).any? ||
        bike.impound_claims_claimed.where(user_id: user.id).any?
    end
  end
end
