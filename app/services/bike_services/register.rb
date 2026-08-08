# frozen_string_literal: true

# The register flow's registration logic (RegisterController)
module BikeServices
  module Register
    extend Functionable

    # Step "3" is the first of the e-vehicle acknowledgment pages
    ACKNOWLEDGMENT_OFFSET = 3
    CONFIRMATION_EMAIL_INTERVAL = 5.minutes

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
      BParam.unexpired_with_token(token)
        .detect { |b| b.creator_id.blank? || b.creator_id == user&.id || b.created_bike_id.present? }
    end

    # The start over link. Destroyed rather than left behind: its token would still
    # resume it, its emailed link would still confirm it, and it would go on alerting
    # its creator to come back to what they discarded
    def discard(session_token:, user:)
      b_param = find_token(session_token:, user:)
      b_param.destroy if b_param.present? && !b_param.with_bike?
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

    # The page after this one, or the review the pages end at
    def step_after(step, sequence:)
      next_index = page_index_for_step(step) + 1
      (next_index < sequence_pages(sequence).count) ? step_for_page_index(next_index) : "review"
    end

    # to_a: callers ask for count/any?/[] repeatedly, and a CollectionProxy re-queries
    # for each of them
    def sequence_pages(sequence)
      sequence&.registration_sequence_pages&.to_a || []
    end

    # The progress bar's segments - one per step the flow can reach
    def total_steps(sequence) = all_steps(sequence_pages(sequence)).count

    # What the acknowledgment eyebrow counts: the rule pages, plus the review they end at
    def acknowledgment_step_count(sequence) = sequence_pages(sequence).count + 1

    # Nothing to agree to without a sequence, otherwise the acknowledgment record
    def acknowledged?(b_param, sequence:)
      sequence_pages(sequence).none? || acknowledgment(b_param).present?
    end

    def acknowledgment(b_param)
      RegistrationSequenceAcknowledgment.find_by(b_param_id: b_param.id)
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

    # What a step's submission agrees to: an acknowledgment page's own boxes, or the
    # single agreement the review ends with
    def acknowledge_step(b_param, step, sequence:, user:, acknowledged_all:, checked:)
      return save_acknowledgment(b_param, sequence, acknowledged_all:, user:) if step == "review"

      acknowledge_page(b_param, page_for_step(step, sequence:), checked:)
    end

    # The moment the pages become an agreement - promoted off the b_param onto a
    # record of its own, which outlives the registration
    def save_acknowledgment(b_param, sequence, acknowledged_all:, user: nil)
      return false unless Binxtils::InputNormalizer.boolean(acknowledged_all) && sequence.present?
      return true if acknowledgment(b_param).present?

      RegistrationSequenceAcknowledgment.create_for(b_param, sequence:, user:).persisted?
    end

    # The bike exists, or everything's entered and awaiting the email
    def finished?(b_param, sequence:)
      return true if b_param.with_bike?

      ready_for_bike?(b_param, sequence:) && !creator_available?(b_param)
    end

    # user: being signed in as the address settles it, without any link being clicked
    def confirmation_email_pending?(b_param, user: nil)
      return false if b_param.self_made?(user)

      b_param.email_unconfirmed? && !creator_available?(b_param)
    end

    # Anonymous registrations can't create a bike - Ownership needs a creator - so the
    # address is emailed a link that proves it. Rate limited: anyone holding the
    # registration's token can ask for a resend
    def send_confirmation_email(b_param)
      return false unless confirmation_email_pending?(b_param)
      return false if b_param.email_confirmation_sent_at.to_i > (Time.current - CONFIRMATION_EMAIL_INTERVAL).to_i

      b_param.generate_email_confirmation_token!
      Email::PartialRegistrationJob.perform_async(b_param.id, "partial_register_confirmation")
      true
    end

    # Time limited, so an old link proves nothing - the address gets a fresh one
    def confirmation_token_valid?(b_param, token)
      return false if b_param.email_confirmation_token_expired?

      Binxtils::Secure.compare?(token, b_param.email_confirmation_token)
    end

    # Whether a bike can be created now - Ownership requires a creator, so
    # anonymous registrations wait for the confirmation email to prove one
    def creator_available?(b_param)
      b_param.creator_id.present? || b_param.creation_organization&.auto_user_id.present? ||
        confirmed_email_creator_id(b_param).present?
    end

    def permitted_step_1_params = %i[manufacturer_id cycle_type owner_email]

    def permitted_step_2_params
      [:primary_frame_color_id, :secondary_frame_color_id, :tertiary_frame_color_id,
        :serial_number, :frame_size, :frame_size_number, :frame_size_unit, :bike_sticker,
        :phone, :status, :frame_model, :year, :user_name, :extra_registration_number,
        :organization_affiliation, :student_id,
        {address_record_attributes: AddressRecord.permitted_params}]
    end

    # Step 1 is the least a registration can be: who owns it and what it is. The params are
    # merged in whether or not it passes, so a re-render still shows everything they entered
    def save_step_1(b_param, bike_params:, propulsion_type_motorized:)
      b_param.clean_params({bike: bike_params, propulsion_type_motorized:}.as_json)
      # Before save, which clears the errors it's about to re-run validations for
      b_param.errors.add(:base, translation(:email_required)) if b_param.owner_email.blank?
      b_param.errors.add(:base, translation(:manufacturer_required)) if b_param.manufacturer_id.blank?
      return false if b_param.errors.any?
      return true if b_param.save

      b_param.errors.add(:base, translation(:unable_to_save))
      false
    end

    # Step 2 merges over step 1 - creator claimed for signed-in users, the photo and the
    # fields into the params json. The photo arrives one of two ways: as bytes from a plain
    # file field, or as the signed id of a blob the browser already uploaded.
    # Returns whether the step passed - a registration for someone else needs their name.
    # A failed step still saves, it just isn't marked complete, so nothing entered is lost
    def save_step_2(b_param, user:, image:, image_signed_id:, bike_params:)
      b_param.creator_id ||= user&.id
      b_param.image = image if image.present?
      bike_params = bike_params.to_h
      completed = b_param.self_made?(user) || bike_params["user_name"].present?
      b_param.clean_params(step_2_params(bike_params, image_signed_id:, completed:).as_json)
      b_param.save
      b_param.errors.add(:base, translation(:name_required)) unless completed
      completed
    end

    # Everything a submission does once its step is saved. Returns the bike, or nil while
    # the registration is still short of one - more to enter, or the email unconfirmed
    def complete(b_param, user:, sequence:, ip_address:)
      claim_creator(b_param, user)
      create_bike_if_ready(b_param, sequence:, ip_address:)
    end

    #
    # private below here
    #

    # Ownership requires a creator, and signing in can happen anywhere in the flow -
    # e.g. partway through the acknowledgment pages
    def claim_creator(b_param, user)
      return if user.blank? || b_param.creator_id.present?

      b_param.update(creator_id: user.id)
    end

    def create_bike_if_ready(b_param, sequence:, ip_address:)
      return nil if b_param.with_bike? || !creator_available?(b_param) ||
        !ready_for_bike?(b_param, sequence:)

      create_bike(b_param, ip_address:)
    end

    def create_bike(b_param, ip_address:)
      b_param.creator_id ||= confirmed_email_creator_id(b_param)
      bike = BikeServices::Creator.new(ip_address:).create_bike(b_param)
      # The bike is what the acknowledgment hangs off once the b_param is swept
      acknowledgment(b_param)&.update(bike_id: bike.id, user_id: b_param.creator_id) if bike.id.present?
      bike
    end

    def ready_for_bike?(b_param, sequence:)
      details_completed?(b_param) && acknowledged?(b_param, sequence:)
    end

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

    # The marker step_2_params sets, that step 2 was submitted with everything it needs
    def details_completed?(b_param)
      b_param.params["details_completed"].present?
    end

    # Blank values keep what step 1 saved - except the additional colors, where
    # blank is the "remove color" button clearing one
    def step_2_params(bike_params, image_signed_id:, completed:)
      bike_params = bike_params.reject { |key, value| value.blank? && !key.in?(%w[secondary_frame_color_id tertiary_frame_color_id]) }
      # The unit only means something alongside a numeric size
      bike_params = bike_params.except("frame_size_unit") if bike_params["frame_size_number"].blank?
      # The photo went browser -> bucket before submit, so only its signed id rides along.
      # Dropped when blank rather than merged, which would clobber an id already stored.
      {details_completed: completed, bike: bike_params, image_signed_id: image_signed_id.presence}.compact
    end

    def translation(key) = I18n.t(key, scope: "shared.register_flow")

    conceal :claim_creator, :create_bike_if_ready, :create_bike, :ready_for_bike?,
      :reusable?, :all_steps, :permitted_steps, :confirmed_email_creator_id,
      :owner_email_for, :assign_owner_email, :details_completed?, :step_2_params,
      :translation
  end
end
