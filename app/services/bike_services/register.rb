# frozen_string_literal: true

# The register flow's registration logic (RegisterController)
module BikeServices
  module Register
    extend Functionable

    # Step "3" is the first of the e-vehicle acknowledgment pages
    ACKNOWLEDGMENT_OFFSET = 3
    CONFIRMATION_EMAIL_INTERVAL = 5.minutes
    # The registrations that report something - a theft, or a vehicle found/abandoned -
    # and the record the report is saved onto, which their bike is created with. Only
    # these two: BikeServices::Builder builds a record for no other status
    REPORT_RECORDS = {"status_stolen" => "stolen_record",
                      "status_impounded" => "impound_record"}.freeze
    # A stolen record carries its own address columns, so the report's location is
    # flattened onto it - the impound record takes the nested attributes as they are
    REPORT_ADDRESS_ATTRS = (AddressRecord.permitted_params - %i[street_2]).freeze
    # The rest of what a theft report asks for. No phone number: a stolen registration
    # gives one in step 2, and the stolen record is built with it
    STOLEN_REPORT_ATTRS = %i[theft_description police_report_number police_report_department
      estimated_value locking_description lock_defeat_description proof_of_ownership
      receive_notifications phone_for_users phone_for_shops phone_for_police].freeze
    # The steps the bike is created from, which it can't take changes to once it exists
    BIKE_STEPS = %w[1 2 report].freeze
    # What a registration can say about its bike past step 1
    MATCHED_ATTRS = %w[frame_model year frame_size primary_frame_color_id secondary_frame_color_id
      tertiary_frame_color_id extra_registration_number status].index_with(&:itself)
      .merge("serial_number" => "serial_normalized", "frame_size_number" => "frame_size").freeze
    MATCH_INPUTS = (MATCHED_ATTRS.keys + %w[owner_email manufacturer_id manufacturer_other cycle_type frame_size_unit]).freeze

    # The token's registration when step 1 was never submitted, otherwise a new one.
    # A signed-in user's email prefills owner_email
    def b_param_for(user:, token_id: nil, status: nil, email: nil, origin: "register_flow")
      status = nil unless Bike.statuses.include?(status)
      existing = find_token(session_token: token_id, user:)
      return assign_start_params(existing, user, email:, status:) if reusable?(existing, origin)

      bike_params = {owner_email: owner_email_for(user, email), status:}.compact
      BParam.create(origin:, creator_id: user&.id, params: {bike: bike_params}.as_json)
    end

    # Resume a registration by token: anonymous, or the passed user's
    def find_token(user:, params_token: nil, session_token: nil) = resume(user:, params_token:, session_token:).first

    # find_token's registration, and whether to sign in for one it couldn't resume: a link to a
    # registration someone signed in started (an organization's resend), visited signed out
    def resume(user:, params_token: nil, session_token: nil)
      token = params_token.presence || session_token.presence
      matches = token.present? ? BParam.unexpired_with_token(token).to_a : []
      b_param = matches.detect { resumable_by?(it, user) }
      [b_param, b_param.blank? && user.blank? && params_token.present? && matches.any?]
    end

    # The start over link. Destroyed rather than left behind: its token would still resume
    # it, and it would go on alerting its creator to come back to what they discarded
    def discard(token:, user:)
      destroy_discardable(find_token(params_token: token, user:))
    end

    # Two waiting at most - the one new lands on and the one before it. Ordered the way
    # the unfinished_registration alert picks its one, so what goes is what it would
    # never have pointed at. Without a bike, since one owing the safety rules is never discarded
    def discard_extra(user:)
      return if user.blank?

      user.b_params.unfinished_registrations.without_bike.reorder(updated_at: :desc).offset(1)
        .each { destroy_discardable(it) }
    end

    # An organization can be named in the URL after the registration starts
    # (/register?...&organization_id=slug), right up until the bike is created. Without one
    # named, who the registrant is stands in - which step 2 offers to drop, so a link's
    # organization clears the marker that puts the offer there
    def assign_organization(b_param, organization, user: nil, passive_organization: nil)
      return if b_param.with_bike?
      # Step 1 posts back the organization it rendered with, which doesn't make an
      # automatic assignment into the named kind
      return assign_auto_organization(b_param, user, passive_organization) if organization.blank? ||
        organization.id == b_param.auto_organization_id
      return if b_param.creation_organization_id.to_s == organization.id.to_s

      b_param.params = b_param.params.except("auto_organization_id")
      b_param.clean_params({bike: {creation_organization_id: organization.id}}.as_json)
      b_param.save
    end

    # The safety rules a registration acknowledges, only for an e-vehicle - the organization's
    # active sequence, or the one its pages are being agreed to from, even once replaced.
    # motorized? first - it's in memory, and creation_organization is a query
    def registration_sequence(b_param)
      return nil unless b_param.motorized?

      organization = b_param.creation_organization
      return nil if organization.blank?

      started_id = b_param.params.dig("registration_sequence", "id")
      (RegistrationSequence.find_by(id: started_id, organization:) if started_id.present?) ||
        RegistrationSequence.active_for(organization)
    end

    # registration_sequence for a link back into the flow, and whether the rules restarted:
    # resuming starts over on the organization's current version rather than finishing one
    # it's replaced since. An agreement already made stands
    def resume_registration_sequence(b_param)
      sequence = registration_sequence(b_param)
      return [sequence, false] if sequence.blank? || sequence.active? || acknowledged?(b_param, sequence:)

      b_param.update(params: b_param.params.except("registration_sequence"))
      [registration_sequence(b_param), true]
    end

    # The step to show: finished once the bike exists (or it's awaiting the email),
    # otherwise the furthest step reached, since every earlier one stays browsable
    def permitted_step(b_param, requested_step, sequence:, steps: nil)
      return "finished" if finished?(b_param, sequence:)

      reached = permitted_steps(b_param, sequence, steps || steps(b_param, sequence:))
      reached.include?(requested_step) ? requested_step : reached.last
    end

    # The sequence page a step renders, or nil for any other step
    def page_for_step(step, sequence:)
      index = page_index_for_step(step)
      sequence_pages(sequence)[index] if index >= 0
    end

    def page_index_for_step(step) = step.to_i - ACKNOWLEDGMENT_OFFSET

    def step_for_page_index(index) = (index + ACKNOWLEDGMENT_OFFSET).to_s

    # What the next and back links go to - nil for the steps nothing comes before or after
    def step_after(step, steps:) = steps[steps.index(step.to_s).to_i + 1]

    def step_before(step, steps:)
      index = steps.index(step.to_s).to_i
      steps[index - 1] if index.positive?
    end

    # to_a: callers ask for count/any?/[] repeatedly, and a CollectionProxy re-queries
    # for each of them
    def sequence_pages(sequence)
      sequence&.registration_sequence_pages&.to_a || []
    end

    # Every step the flow reaches, in order - what the progress bar counts off and the back
    # links walk. The report comes right after step 2, unless the registration is waiting on
    # its confirmation email: the emailed link is what proves the address the report belongs
    # to, and it's clicked after the acknowledgment pages rather than before them.
    # Placing it asks whether there's a creator yet, which is a query, so this is built once
    # a request and passed down
    def steps(b_param, sequence:)
      pages = sequence_pages(sequence)
      rest = pages.each_index.map { step_for_page_index(it) } + (pages.any? ? %w[review] : [])
      return %w[1 2] + rest unless report_step?(b_param&.status)

      creator_available?(b_param) ? %w[1 2 report] + rest : %w[1 2] + rest + %w[report]
    end

    # Whether the flow includes the report step - what was stolen, or what was found
    def report_step?(status) = REPORT_RECORDS.key?(status)

    # What the acknowledgment eyebrow counts: the rule pages, plus the review they end at
    def acknowledgment_step_count(sequence) = sequence_pages(sequence).count + 1

    # Nothing to agree to without a sequence, otherwise the acknowledgment record
    def acknowledged?(b_param, sequence:)
      sequence_pages(sequence).none? || RegistrationSequenceAcknowledgment.acknowledged.exists?(b_param_id: b_param.id)
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

    # The moment the pages become an agreement, on a record that outlives the registration
    def save_acknowledgment(b_param, sequence, acknowledged_all:, user: nil)
      return false unless Binxtils::InputNormalizer.boolean(acknowledged_all) && sequence.present?
      return true if acknowledged?(b_param, sequence:)
      return false unless RegistrationSequenceAcknowledgment.acknowledge(b_param, sequence:, user:)

      send_held_email(b_param) if b_param.with_bike?
      true
    end

    # The bike exists with its rules agreed to, or everything reachable is entered and awaiting
    # the email - the report step waits on that same confirmation, so it isn't what's left here
    def finished?(b_param, sequence:)
      return !acknowledgment_owed?(b_param, sequence:) if b_param.with_bike?

      details_completed?(b_param) && acknowledged?(b_param, sequence:) && !creator_available?(b_param)
    end

    # The bike is created before the safety rules, which the registration still has to agree
    # to - unless the sequence has since gone, leaving nothing to agree to
    def acknowledgment_owed?(b_param, sequence:)
      b_param.acknowledgment_pending? && sequence_pages(sequence).any?
    end

    def editable_step?(b_param, step) = !b_param.with_bike? || BIKE_STEPS.exclude?(step)

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
      # Not in confirmation_email_pending? - both steps read that to render "link sent"
      return false if b_param.likely_spam?
      return false if b_param.email_confirmation_sent_at.to_i > (Time.current - CONFIRMATION_EMAIL_INTERVAL).to_i

      b_param.generate_email_confirmation_token!
      EmailJobs::PartialRegistrationJob.perform_async(b_param.id, "partial_register_confirmation")
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
    def save_step_1(b_param, bike_params:, propulsion_type_motorized:, additional: nil)
      bike_params = honeypot_spam(bike_params, additional)
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
    def save_step_2(b_param, user:, image:, image_signed_id:, bike_params:, register_with_organization: nil, additional: nil)
      b_param.creator_id ||= user&.id
      b_param.image = image if image.present?
      bike_params = honeypot_spam(bike_params, additional)
      completed = b_param.self_made?(user) || bike_params["user_name"].present?
      clear_stale_report(b_param, bike_params["status"])
      set_auto_organization(b_param, register_with_organization)
      b_param.clean_params(step_2_params(bike_params, image_signed_id:, completed:).as_json)
      b_param.save
      b_param.errors.add(:base, translation(:name_required)) unless completed
      completed
    end

    def permitted_report_params
      %i[date timezone impounded_description] + STOLEN_REPORT_ATTRS +
        [{address_record_attributes: AddressRecord.permitted_params}]
    end

    # The theft or the find itself, onto the record the bike is created with - a stolen
    # record for a theft, an impound record for a vehicle found. Returns whether the step
    # passed; a failed one still saves, so nothing entered is lost on the re-render
    def save_report(b_param, report_params:)
      attrs = report_params.to_h.with_indifferent_access
      date = Binxtils::TimeParser.parse(attrs["date"], attrs["timezone"], parse_error: :nil)
      errors = report_errors(b_param, attrs, date)
      report = b_param.status_stolen? ? stolen_report_attrs(attrs, date) : impound_report_attrs(attrs, date)
      b_param.clean_params({REPORT_RECORDS[b_param.status] => report, :report_completed => errors.none?}.as_json)
      b_param.save
      errors.each { b_param.errors.add(:base, it) }
      errors.none?
    end

    # Everything a submission does once its step is saved. Returns the bike, or nil while the
    # registration is short of finished - more to enter, the email unconfirmed, or rules owed
    def complete(b_param, user:, sequence:, ip_address:)
      claim_creator(b_param, user)
      return create_bike_if_ready(b_param, sequence:, ip_address:) unless b_param.with_bike?

      b_param.created_bike unless acknowledgment_owed?(b_param, sequence:)
    end

    # The finished registration email the pending acknowledgment held back - the job
    # decides whether it goes, it just no longer has a reason to hold it
    def send_held_email(b_param)
      EmailJobs::OwnershipInvitationJob.perform_async(b_param.created_bike.current_ownership_id)
    end

    # The unfinished registrations a new bike completes: every register flow registration of it -
    # registering it some other way is what they were abandoned for - and the likeliest embed_partial
    def matching_partial_registrations(bike)
      return [] if bike.owner_email.blank?

      register_flow, embed = BParam.partial_registrations.email_search(bike.owner_email)
        .reorder(:created_at).partition(&:register_flow?)
      embed_match = (embed.select { it.manufacturer_id == bike.manufacturer_id }.presence || embed).last
      register_flow.select { matches_bike?(it, bike) } + [embed_match].compact
    end

    #
    # private below here
    #

    # Whether a bike registered some other way is this registration's. Step 1 says only
    # what it is, so any bike of that make and type is; whatever came after has to match too
    def matches_bike?(b_param, bike)
      bike_attrs = b_param.safe_bike_attrs({}).slice(*MATCH_INPUTS)
      # The one taken as submitted rather than off a reader that guards it - a cycle_type
      # Bike's enum doesn't have (and raises assigning) is one no bike has either
      return false if bike_attrs["cycle_type"].present? && !Bike.cycle_types.key?(bike_attrs["cycle_type"])

      built = Bike.new(bike_attrs)
      built.set_calculated_unassociated_attributes
      attrs = %w[owner_email mnfg_name cycle_type] + MATCHED_ATTRS.filter_map { |key, attr| attr if b_param.bike[key].present? }
      built.slice(*attrs) == bike.slice(*attrs)
    end

    # The one the registrant belongs to, or failing that the one their other bikes are
    # registered with. Two of either says nothing about this bike, so it stays unattributed
    def auto_organization(user)
      organizations = user.organizations.limit(2).to_a
      organizations = user.bike_organizations.limit(2).to_a if organizations.none?
      organizations.first if organizations.one?
    end

    # Once, and not past step 2 - step 2's checkbox is the only chance to decline, and
    # dropping it there leaves the marker behind saying the organization was taken.
    # The passive organization is the one they're currently acting as, which says which
    # of several theirs this registration is for
    def assign_auto_organization(b_param, user, passive_organization = nil)
      return if user.blank? || b_param.auto_organization_assigned? ||
        b_param.creation_organization_id.present? || details_completed?(b_param)

      organization = passive_organization || auto_organization(user)
      bike = {creation_organization_id: organization.id} if organization.present?
      b_param.clean_params({auto_organization_id: organization&.id || 0, bike:}.compact.as_json)
      b_param.save
    end

    # Step 2's "register with" checkbox, which only an automatic assignment gets. The
    # marker stays when it's unchecked, so the checkbox is still there to change their
    # mind. Runs before clean_params, which is what puts the organization_id column in step
    def set_auto_organization(b_param, register_with_organization)
      return if b_param.auto_organization_id.blank?

      if Binxtils::InputNormalizer.boolean(register_with_organization)
        b_param.creation_organization_id = b_param.auto_organization_id
      else
        b_param.params = b_param.params.merge("bike" => b_param.bike.except("creation_organization_id"))
      end
    end

    # Ownership requires a creator, and signing in can happen anywhere in the flow -
    # e.g. partway through the acknowledgment pages
    def claim_creator(b_param, user)
      return if user.blank? || b_param.creator_id.present?

      b_param.update(creator_id: user.id)
    end

    def create_bike_if_ready(b_param, sequence:, ip_address:)
      return nil if !creator_available?(b_param) || !details_completed?(b_param) ||
        !report_completed?(b_param)

      create_bike(b_param, sequence:, ip_address:)
    end

    # Returns nil while the rules are owed - the bike exists, but the registration isn't finished
    def create_bike(b_param, sequence:, ip_address:)
      b_param.creator_id ||= confirmed_email_creator_id(b_param)
      # Ahead of the bike, so the ownership it creates holds its email back
      pending = RegistrationSequenceAcknowledgment.create_pending(b_param, sequence:) unless acknowledged?(b_param, sequence:)
      bike = BikeServices::Creator.new(ip_address:).create_bike(b_param)
      if bike.id.blank?
        pending&.destroy
        return bike
      end

      # The bike is what the acknowledgment hangs off once the b_param is swept. The creator
      # only stands in for whoever agreed - nobody was signed in to be recorded as it
      acknowledgment = pending || RegistrationSequenceAcknowledgment.find_by(b_param_id: b_param.id)
      acknowledgment&.update(bike_id: bike.id, user_id: acknowledgment.user_id || b_param.creator_id)
      bike if pending.blank?
    end

    # Nothing to report without a status that has a record, otherwise save_report's marker
    def report_completed?(b_param)
      !report_step?(b_param.status) || b_param.params["report_completed"].present?
    end

    # Step 2 can change the status after the report was filled in, and BParam reads the
    # status back off the record that saved it - so a record the new status has no use for
    # would pin the registration to the old one. Dropped, along with save_report's marker
    def clear_stale_report(b_param, status)
      return if status.blank?

      stale = REPORT_RECORDS.except(status).values & b_param.params.keys
      b_param.params = b_param.params.except(*stale, "report_completed") if stale.any?
    end

    # Both reports have to say when and where, each in its own words - everything else
    # on the step is optional
    def report_errors(b_param, attrs, date)
      return [] unless report_step?(b_param.status)

      report = b_param.status_stolen? ? "stolen" : "found"
      address = attrs["address_record_attributes"] || {}
      [(translation(:"date_#{report}_required") if date.blank?),
        (translation(:"location_#{report}_required") if address["street"].blank? || address["city"].blank?)].compact
    end

    def stolen_report_attrs(attrs, date)
      address = attrs["address_record_attributes"] || {}
      attrs.slice(*STOLEN_REPORT_ATTRS)
        .merge(address.slice(*REPORT_ADDRESS_ATTRS))
        .merge("date_stolen" => date).compact
    end

    def impound_report_attrs(attrs, date)
      {"impounded_at" => date, "impounded_description" => attrs["impounded_description"],
       "address_record_attributes" => attrs["address_record_attributes"]}.compact
    end

    # Its creator, or the owner it's for - staff registering for someone leaves them the creator.
    # Anyone once the registration is finished, since the token then only shows the completion page
    def resumable_by?(b_param, user)
      b_param.creator_id.blank? || b_param.finished_registration? ||
        b_param.creator_id == user&.id || b_param.self_made?(user)
    end

    # manufacturer_id is the submitted-step-1 marker. Matching origin, so arriving from an
    # organization's page doesn't take over a shell started on /register and register the
    # bike as though it came in there
    def reusable?(b_param, origin)
      b_param.present? && !b_param.with_bike? && b_param.manufacturer_id.blank? &&
        b_param.origin == origin
    end

    # Kept once a confirmation link is out - that email promises the address it can still
    # finish this registration
    def destroy_discardable(b_param)
      return unless b_param&.register_flow? && !b_param.with_bike? &&
        b_param.email_confirmation_sent_at.blank?

      b_param.destroy
    end

    # Every step the registration has reached, in order - each one opens the next, so the
    # flow stops at the first that hasn't been done
    def permitted_steps(b_param, sequence, steps)
      reached = steps.take_while { step_completed?(b_param, it, sequence:) }.count
      steps.first(reached + 1).select { editable_step?(b_param, it) }
    end

    # Whether a step has been submitted with everything it asks for
    def step_completed?(b_param, step, sequence:)
      case step
      when "1" then b_param.manufacturer_id.present?
      when "2" then details_completed?(b_param)
      when "report" then report_completed?(b_param)
      when "review" then acknowledged?(b_param, sequence:)
      else acknowledged_page_ids(b_param).include?(page_for_step(step, sequence:)&.id)
      end
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

    # A reused registration takes what the link named - the status whenever one is named,
    # the same way assign_organization takes the organization, since the link is how a
    # theft says it's a theft. A link that names neither leaves both alone
    def assign_start_params(b_param, user, email:, status:)
      named_status = {status:} if status.present? && status != b_param.bike["status"]
      bike_params = reused_owner_email(b_param, user, email).merge(named_status || {})
      return b_param if bike_params.none?

      b_param.clean_params({bike: bike_params}.as_json)
      b_param.save
      b_param
    end

    # The address it has unless email asked otherwise - through clean_params, since
    # owner_email= ignores a blank value
    def reused_owner_email(b_param, user, email)
      return {} if email.blank? && b_param.owner_email.present?

      owner_email = owner_email_for(user, email)
      (owner_email == b_param.owner_email) ? {} : {owner_email:}
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

    # Merged rather than assigned, so a resubmission without the honeypot doesn't
    # clear a flag already earned
    def honeypot_spam(bike_params, additional)
      additional.present? ? bike_params.to_h.merge("likely_spam" => true) : bike_params.to_h
    end

    conceal :matches_bike?, :auto_organization, :assign_auto_organization, :set_auto_organization,
      :claim_creator, :create_bike_if_ready, :create_bike,
      :report_completed?, :clear_stale_report, :report_errors, :stolen_report_attrs,
      :impound_report_attrs, :resumable_by?, :reusable?, :destroy_discardable, :permitted_steps, :step_completed?,
      :confirmed_email_creator_id, :owner_email_for, :assign_start_params, :reused_owner_email, :details_completed?,
      :step_2_params, :translation, :honeypot_spam
  end
end
