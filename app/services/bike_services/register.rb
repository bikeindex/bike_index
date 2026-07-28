# frozen_string_literal: true

# The register flow's registration logic (RegisterController)
module BikeServices
  module Register
    extend Functionable

    # The token's registration when step 1 was never submitted (redirecting into
    # it can't surprise anyone), otherwise a new one. A signed-in user's email
    # prefills owner_email - manufacturer_id is the submitted-step-1 marker.
    def b_param_for(user:, token_id: nil, organization_id: nil, status: nil)
      existing = find_token(session_token: token_id, user:)
      return prefill_owner_email(existing, user) if reusable?(existing)

      bike_params = {
        owner_email: user&.email,
        status: (status if Bike.statuses.include?(status)),
        creation_organization_id: organization_id
      }.compact
      BParam.create(origin: "registration_flow", creator_id: user&.id, params: {bike: bike_params}.as_json)
    end

    # Resume a registration by token: anonymous or created by the passed user
    def find_token(user:, params_token: nil, session_token: nil)
      token = params_token.presence || session_token.presence
      return if token.blank?

      # Once the bike exists the token only ever shows the completion page, so
      # access doesn't require matching the creator assigned at creation
      BParam.recent_with_token(token)
        .detect { |b| b.creator_id.blank? || b.creator_id == user&.id || b.created_bike_id.present? }
    end

    # The step to show: finished once the bike exists (or it's awaiting the
    # email), step 1 until it's submitted - then 1 and 2 both stay browsable
    def permitted_step(b_param, requested_step)
      if finished?(b_param)
        "finished"
      elsif b_param.manufacturer_id.blank?
        "1"
      else
        (requested_step == "1") ? "1" : "2"
      end
    end

    # The bike exists, or everything's entered and awaiting the email
    def finished?(b_param)
      b_param.with_bike? || (b_param.details_completed? && !creator_available?(b_param))
    end

    # Whether a bike can be created now - Ownership requires a creator, so
    # anonymous registrations wait for the confirmation email to prove one
    def creator_available?(b_param)
      b_param.creator_id.present? || b_param.creation_organization&.auto_user_id.present? ||
        b_param.confirmed_email_creator_id.present?
    end

    # Step 2 merges over step 1 - creator claimed for signed-in users, the
    # photo onto b_param.image, the fields into the params json
    def save_step_2(b_param, user:, image:, bike_params:)
      b_param.creator_id ||= user&.id
      b_param.image = image if image.present?
      b_param.clean_params(step_2_params(bike_params.to_h).as_json)
      b_param.save
    end

    # The emailed token proves control of the address. Returns the created bike,
    # :details_pending after confirming an unfinished registration, or :invalid
    def confirm_email(b_param, confirmation_token:, ip_address:)
      expected = b_param.confirmation_token
      unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(confirmation_token.to_s, expected)
        return :invalid
      end

      b_param.confirm_email!
      return :details_pending unless b_param.details_completed?

      create_bike(b_param, ip_address:)
    end

    # Saves, sending the partial-registration email when this address hasn't
    # gotten one - so resubmitting step 1 only re-sends to a new address
    def save_step_1(b_param)
      send_email = b_param.partial_email_sent_to != b_param.owner_email
      b_param.params = b_param.params.merge("partial_email_sent_to" => b_param.owner_email) if send_email
      return false unless b_param.save

      Email::PartialRegistrationJob.perform_async(b_param.id) if send_email
      true
    end

    def create_bike(b_param, ip_address:)
      b_param.creator_id ||= b_param.confirmed_email_creator_id
      BikeServices::Creator.new(ip_address:).create_bike(b_param)
    end

    #
    # private below here
    #

    def reusable?(b_param)
      b_param.present? && !b_param.with_bike? && b_param.manufacturer_id.blank?
    end

    def prefill_owner_email(b_param, user)
      return b_param if user.nil? || b_param.owner_email.present?

      b_param.owner_email = user.email
      b_param.save
      b_param
    end

    # Blank values keep what step 1 saved - except the additional colors, where
    # blank is the "remove color" button clearing one
    def step_2_params(bike_params)
      bike_params = bike_params.reject { |key, value| value.blank? && !key.in?(%w[secondary_frame_color_id tertiary_frame_color_id]) }
      # The unit only means something alongside a numeric size
      bike_params = bike_params.except("frame_size_unit") if bike_params["frame_size_number"].blank?
      {details_completed: true, bike: bike_params}
    end

    conceal :reusable?, :prefill_owner_email, :step_2_params
  end
end
