# Contains methods used for display. Trying this out instead of decorators
# ... obviously, this adds one more place to look for methods on bikes, but whatever
class BikeDisplayer
  # Not sure if I like everything being class methods, but doing that for now anyway
  class << self
    def display_contact_owner?(bike, user = nil)
      bike.current_stolen_record.present?
    end

    def display_impound_claim?(bike, user = nil)
      return false if bike.owner.present? && bike.owner == user
      return true if bike.current_impound_record.present?
      return false if user.blank?
      bike.impound_claims_submitting.active.where(user_id: user.id).any? ||
        bike.impound_claims_claimed.active.where(user_id: user.id).any?
    end

    def display_sticker_edit?(bike, user = nil)
      return false unless user.present?
      return true if user.superuser? || user.enabled?("bike_stickers")
      # user_can_claim_sticker? checks if they've made to many sticker updates
      return false unless BikeSticker.user_can_claim_sticker?(user)
      return true if bike.bike_stickers.any? || user.bike_sticker_updates.any?
      bike_ids = user.rough_approx_bikes.pluck(:id)
      # Any bikes with bike stickers
      return false unless bike_ids.any?
      return true if BikeStickerUpdate.where(bike_id: bike_ids).any?
      # Any organizations, for any bikes from user, with stickers
      Organization.where(id: BikeOrganization.where(bike_id: bike_ids).pluck(:organization_id))
        .with_enabled_feature_slugs("bike_stickers").any?
    end
  end
end
