# Contains methods used for display, which don't return HTML.
# Use BikeHelper for methods that do return HTML

# TODO: Figure out a more consistent way of handling Displayers while preserving Functionalness
class BikeDisplayer
  # Not sure if I like everything being class methods, but doing that for now anyway because functional-ish
  class << self
    # This is just a quick hack, will improve
    def vehicle_search?(params_and_interpreted_params)
      (%i[propulsion_type cycle_type] & params_and_interpreted_params.keys).any? ||
        params_and_interpreted_params[:search_model_audit_id].present?
    end

    # user arg because all methods have it
    def paint_description?(bike, _user = nil)
      bike.pos? && bike.paint.present?
    end

    # Users send unstolen notifications through the organized_access_panel
    # The contact owner box only shows up for stolen bikes
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
      return false unless user.present? && !bike.version?
      return true if user.superuser? || user.enabled?("bike_stickers")
      # user_can_claim_sticker? checks if they've made too many sticker updates
      return false unless BikeSticker.user_can_claim_sticker?(user)
      return true if bike.bike_stickers.any?(&:user_editable?) ||
        user.updated_bike_stickers.any?(&:user_editable?)

      bike_ids = user.bike_ids
      # Return false if no bikes
      return false if bike_ids.none?
      sticker_ids = BikeStickerUpdate.where(bike_id: bike_ids).distinct.pluck(:bike_sticker_id)
      return true if BikeSticker.where(id: sticker_ids).any?(&:user_editable?)
      # Any organizations, for any bikes from user, with stickers
      Organization.where(id: BikeOrganization.where(bike_id: bike_ids).pluck(:organization_id))
        .with_enabled_feature_slugs("bike_stickers_user_editable").any?
    end

    def display_edit_address_fields?(bike, user = nil)
      return false unless user_edit_bike_address?(bike, user)
      # Make absolutely sure with stolen bikes
      return false if bike.version? || bike.current_stolen_record_id.present?
      # parking notifications, impounded, stolen etc use the associated record for their address
      %w[status_impounded unregistered_parking_notification status_stolen].exclude?(bike.status)
    end

    # Intended as an internal method, splitting out for testing purposes
    def user_edit_bike_address?(bike, user = nil)
      return false if user.blank?
      if bike.user.present?
        # If the user has set their address, that's the only way to update bike addresses
        return false if bike.user.address_set_manually
        if bike.user == user
          # If user is bike owner, check for user_registration_organizations with reg_address -
          # because then they need to edit address via their account page
          return user.uro_organizations.with_enabled_feature_slugs("reg_address").none?
        end
      end
      # otherwise if bike is new, for superusers or users authorized by organization
      bike.id.blank? || user.superuser? || bike.authorized_by_organization?(u: user)
    end

    def edit_street_address?(bike, user = nil)
      return false if bike.user&.no_address? || bike.creation_organization&.enabled?("no_address")
      bike.street.present? || bike.creation_organization&.enabled?("reg_address")
    end

    def thumb_image_url(bike)
      return bike.thumb_path if bike.thumb_path.present?
      return nil if bike.stock_photo_url.blank?
      small = bike.stock_photo_url.split("/")
      ext = "/small_" + small.pop
      small.join("/") + ext
    end
  end
end
