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
      BParam.create(origin: "register_flow", creator_id: user&.id, params: {bike: bike_params}.as_json)
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

    # An organization can be named in the URL after the registration starts
    # (/register?...&organization_id=slug), right up until the bike is created
    def assign_organization(b_param, organization)
      return if organization.blank? || b_param.with_bike? ||
        b_param.creation_organization_id.to_s == organization.id.to_s

      b_param.clean_params({bike: {creation_organization_id: organization.id}}.as_json)
      b_param.save
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
      b_param.with_bike? || (details_completed?(b_param) && !creator_available?(b_param))
    end

    # Whether a bike can be created now - Ownership requires a creator, so
    # anonymous registrations wait for the confirmation email to prove one
    def creator_available?(b_param)
      b_param.creator_id.present? || b_param.creation_organization&.auto_user_id.present? ||
        confirmed_email_creator_id(b_param).present?
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
      return :details_pending unless details_completed?(b_param)

      create_bike(b_param, ip_address:)
    end

    # Saves, sending the partial-registration email when this address hasn't
    # gotten one - so resubmitting step 1 only re-sends to a new address. A
    # signed-in registration creates the bike at step 2, with nothing to confirm
    def save_step_1(b_param, user:)
      send_email = user.blank? && b_param.partial_email_sent_to != b_param.owner_email
      b_param.params = b_param.params.merge("partial_email_sent_to" => b_param.owner_email) if send_email
      return false unless b_param.save

      Email::PartialRegistrationJob.perform_async(b_param.id) if send_email
      true
    end

    def create_bike(b_param, ip_address:)
      b_param.creator_id ||= confirmed_email_creator_id(b_param)
      BikeServices::Creator.new(ip_address:).create_bike(b_param)
    end

    #
    # private below here
    #

    def reusable?(b_param)
      b_param.present? && !b_param.with_bike? && b_param.manufacturer_id.blank?
    end

    # The confirmed email's own account, or the AUTO_ORG_MEMBER system user standing in
    def confirmed_email_creator_id(b_param)
      return nil unless b_param.email_confirmed?

      (User.fuzzy_email_find(b_param.owner_email) || User.fuzzy_email_find(ENV["AUTO_ORG_MEMBER"]))&.id
    end

    def prefill_owner_email(b_param, user)
      return b_param if user.nil? || b_param.owner_email.present?

      b_param.owner_email = user.email
      b_param.save
      b_param
    end

    # The marker step_2_params sets, that step 2 has been submitted
    def details_completed?(b_param)
      b_param.params["details_completed"].present?
    end

    # Blank values keep what step 1 saved - except the additional colors, where
    # blank is the "remove color" button clearing one
    def step_2_params(bike_params)
      bike_params = bike_params.reject { |key, value| value.blank? && !key.in?(%w[secondary_frame_color_id tertiary_frame_color_id]) }
      # The unit only means something alongside a numeric size
      bike_params = bike_params.except("frame_size_unit") if bike_params["frame_size_number"].blank?
      {details_completed: true, bike: bike_params}
    end

    conceal :reusable?, :confirmed_email_creator_id, :prefill_owner_email,
      :details_completed?, :step_2_params
  end
end
