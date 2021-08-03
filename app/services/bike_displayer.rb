# Contains methods used for display, which don't return HTML.
# Use BikeHelper for methods that do return HTML
class BikeDisplayer
  # Not sure if I like everything being class methods, but doing that for now anyway because functional-ish
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
      # user_can_claim_sticker? checks if they've made too many sticker updates
      return false unless BikeSticker.user_can_claim_sticker?(user)
      return true if bike.bike_stickers.any?(&:user_editable?) ||
        user.updated_bike_stickers.any?(&:user_editable?)

      bike_ids = user.rough_approx_bikes.pluck(:id)
      # Return false if no bikes
      return false if bike_ids.none?
      sticker_ids = BikeStickerUpdate.where(bike_id: bike_ids).distinct.pluck(:bike_sticker_id)
      return true if BikeSticker.where(id: sticker_ids).any?(&:user_editable?)
      # Any organizations, for any bikes from user, with stickers
      Organization.where(id: BikeOrganization.where(bike_id: bike_ids).pluck(:organization_id))
        .with_enabled_feature_slugs("bike_stickers_user_editable").any?
    end

    def display_edit_address_fields?(bike, user = nil)
      # Only display for the current owner of the bike, *not* anyone who is authorized for the bike
      return false unless user.present? && bike.user == user
      # If the user has set their address, that's the only way to update bike addresses
      return false if user.address_set_manually
      # Make sure new bikes
      return false if bike.current_stolen_record.present?
      # parking notifications, impounded, stolen etc use the associated record for their address
      %w[status_impounded unregistered_parking_notification status_stolen].exclude?(bike.status)
    end
  end
end
