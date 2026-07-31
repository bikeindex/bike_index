# frozen_string_literal: true

# The register flow's registration logic (RegisterController)
module BikeServices
  module Register
    extend Functionable

    # Step "3" is the first of the e-vehicle acknowledgment pages
    ACKNOWLEDGMENT_OFFSET = 3

    # The token's registration when step 1 was never submitted (redirecting into
    # it can't surprise anyone), otherwise a new one. A signed-in user's email
    # prefills owner_email - manufacturer_id is the submitted-step-1 marker.
    def b_param_for(user:, token_id: nil, status: nil, email: nil)
      existing = find_token(session_token: token_id, user:)
      return assign_owner_email(existing, user, email) if reusable?(existing)

      bike_params = {
        owner_email: owner_email_for(user, email),
        status: (status if Bike.statuses.include?(status))
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

    # The safety rules a registration acknowledges before its bike is created - the
    # organization's active sequence, and only for an e-vehicle
    def registration_sequence(b_param)
      organization = b_param.creation_organization
      RegistrationSequence.active_for(organization) if b_param.motorized? && organization.present?
    end

    # The step to show: finished once the bike exists (or it's awaiting the email),
    # otherwise the furthest step reached, since every earlier one stays browsable
    def permitted_step(b_param, requested_step, sequence:)
      return "finished" if finished?(b_param, sequence:)

      steps = permitted_steps(b_param, sequence)
      steps.include?(requested_step) ? requested_step : steps.last
    end

    # The sequence page a step renders, or nil for any other step
    def page_for_step(step, sequence:)
      index = page_index_for_step(step)
      sequence_pages(sequence)[index] if index >= 0
    end

    def page_index_for_step(step) = step.to_i - ACKNOWLEDGMENT_OFFSET

    def step_for_page_index(index) = (index + ACKNOWLEDGMENT_OFFSET).to_s

    # to_a: callers ask for count/any?/[] repeatedly, and a CollectionProxy re-queries
    # for each of them
    def sequence_pages(sequence)
      sequence&.registration_sequence_pages&.to_a || []
    end

    # The progress bar's segments - one per step the flow can reach
    def total_steps(sequence) = all_steps(sequence_pages(sequence)).count

    # Nothing to agree to without a sequence, otherwise the attestation record
    def attested?(b_param, sequence:)
      sequence_pages(sequence).none? || attestation(b_param).present?
    end

    def attestation(b_param)
      RegistrationSequenceAttestation.find_by(b_param_id: b_param.id)
    end

    # Which pages have been acknowledged so far. In-flight progress, so it lives on
    # the b_param alongside the rest of the wizard's state
    def acknowledged_page_ids(b_param)
      b_param.params.dig("registration_sequence", "acknowledged_page_ids") || []
    end

    # All or nothing: a page is only acknowledged with every one of its rules checked
    # (an unchecked box submits nothing, so the lengths only match when they all did)
    def acknowledge_page(b_param, page, checked:)
      bullets = page&.bullets || []
      agreed = Array(checked)
      return false if bullets.none? || agreed.length != bullets.length ||
        !agreed.all? { Binxtils::InputNormalizer.boolean(it) }

      # id alongside the pages, so the acknowledged ids are unambiguously scoped
      b_param.clean_params({registration_sequence: {id: page.registration_sequence_id,
                                                    acknowledged_page_ids: (acknowledged_page_ids(b_param) + [page.id]).uniq}}.as_json)
      b_param.save
    end

    # The moment the pages become an agreement - promoted off the b_param onto a
    # record of its own, which outlives the registration
    def save_attestation(b_param, sequence, attested:, user: nil)
      return false unless Binxtils::InputNormalizer.boolean(attested) && sequence.present?
      return true if attestation(b_param).present?

      RegistrationSequenceAttestation.create_for(b_param, sequence:, user:).persisted?
    end

    # The bike exists, or everything's entered and awaiting the email
    def finished?(b_param, sequence:)
      return true if b_param.with_bike?

      details_completed?(b_param) && attested?(b_param, sequence:) && !creator_available?(b_param)
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

    # Ownership requires a creator, and signing in can happen anywhere in the flow -
    # e.g. partway through the acknowledgment pages
    def claim_creator(b_param, user)
      return if user.blank? || b_param.creator_id.present?

      b_param.update(creator_id: user.id)
    end

    def create_bike(b_param, ip_address:)
      b_param.creator_id ||= confirmed_email_creator_id(b_param)
      bike = BikeServices::Creator.new(ip_address:).create_bike(b_param)
      # The bike is what the attestation hangs off once the b_param is swept
      attestation(b_param)&.update(bike_id: bike.id, user_id: b_param.creator_id) if bike.id.present?
      bike
    end

    #
    # private below here
    #

    def reusable?(b_param)
      b_param.present? && !b_param.with_bike? && b_param.manufacturer_id.blank?
    end

    # Every step the flow reaches with these pages, in order
    def all_steps(pages)
      return %w[1 2] if pages.none?

      %w[1 2] + pages.each_index.map { step_for_page_index(it) } + %w[review]
    end

    # Every step the registration has reached, in order - the acknowledgment pages
    # open one at a time, and the review once they're all acknowledged
    def permitted_steps(b_param, sequence)
      return %w[1] if b_param.manufacturer_id.blank?

      pages = sequence_pages(sequence)
      return %w[1 2] unless details_completed?(b_param) && pages.any?

      acknowledged = acknowledged_page_ids(b_param)
      reached = pages.take_while { acknowledged.include?(it.id) }.count
      all_steps(pages).first(ACKNOWLEDGMENT_OFFSET + reached)
    end

    # The confirmed email's own account, or the AUTO_ORG_MEMBER system user standing in
    def confirmed_email_creator_id(b_param)
      return nil unless b_param.email_confirmed?

      (User.fuzzy_email_find(b_param.owner_email) || User.fuzzy_email_find(ENV["AUTO_ORG_MEMBER"]))&.id
    end

    # "false" leaves the address blank even for a signed-in user, any other value
    # stands in for theirs, and blank falls back to it
    def owner_email_for(user, email)
      return nil if email.to_s == "false"

      email.presence || user&.email
    end

    # A reused registration keeps the address it has unless email asked otherwise -
    # through clean_params, since owner_email= ignores a blank value
    def assign_owner_email(b_param, user, email)
      return b_param if email.blank? && b_param.owner_email.present?

      owner_email = owner_email_for(user, email)
      return b_param if owner_email == b_param.owner_email

      b_param.clean_params({bike: {owner_email:}}.as_json)
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

    conceal :reusable?, :all_steps, :permitted_steps, :confirmed_email_creator_id,
      :owner_email_for, :assign_owner_email, :details_completed?, :step_2_params
  end
end
