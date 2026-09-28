# frozen_string_literal: true

# The organization signup flow (OrganizationSignupController). Everything waits on the
# OrganizationSignup until the emailed link proves the address - only then are the
# organization and its admin's account created, so an unconfirmed signup leaves nothing behind
module OrgServices
  module Signup
    extend Functionable

    CONFIRMATION_EMAIL_INTERVAL = 5.minutes
    STEPS = %w[1 2 finished].freeze
    # The state (or region) isn't here: which one a country has is the form's to decide
    REQUIRED_ADDRESS_ATTRS = %w[street city postal_code country_id].freeze
    # What Pages::Register::Parts::Progress reads off a flow
    FLOW = Data.define do
      def steps = STEPS

      def position(step) = STEPS.index(step.to_s).to_i + 1
    end.new

    # The session's signup, while it's still one - once its organization exists there's
    # nothing left to go back to
    def find(token)
      OrganizationSignup.unexpired.without_organization.find_by(id_token: token) if token.present?
    end

    def start(user:) = OrganizationSignup.create!(creator: user, email: user&.email)

    # The step asked for, if the signup has reached it - otherwise the furthest it has.
    # Step 1 is only saved once it's valid, so a name means it's done
    def permitted_step(signup, step)
      furthest = if signup.name.blank? then "1"
      elsif signup.details_completed? then "finished"
      else
        "2"
      end
      ((STEPS.index(step.to_s) || STEPS.count) <= STEPS.index(furthest)) ? step.to_s : furthest
    end

    # A signed in user's own address is the one confirmed - they aren't asked for it.
    # Changing the address makes the link already sent useless, so it's replaced
    def save_start(signup, user:, name:, kind:, email:, additional: nil)
      email = EmailNormalizer.normalize(user&.email || email)
      if email != signup.email
        signup.assign_attributes(email_confirmation_token: nil, email_confirmation_sent_at: nil, email_confirmed_at: nil)
      end
      signup.assign_attributes(name:, email:, kind: (kind if Organization.user_creatable_kinds.include?(kind)),
        likely_spam: signup.likely_spam || additional.present?)
      start_errors(signup).each { signup.errors.add(:base, it) }
      signup.errors.none? && signup.save
    end

    # Saved whether or not it passes, so a re-render has everything they entered
    def save_details(signup, website:, phone:, publicly_visible:, address:)
      address = address.to_h.stringify_keys.slice(*AddressRecord.permitted_params.map(&:to_s)).compact_blank
      missing = REQUIRED_ADDRESS_ATTRS.any? { address[it].blank? }
      signup.update(website:, phone:, address:, publicly_visible: Binxtils::InputNormalizer.boolean(publicly_visible),
        details_completed_at: (Time.current unless missing))
      signup.errors.add(:base, translation(:address_required)) if missing
      !missing
    end

    # Rate limited: anyone holding the signup's session can ask for a resend. The link already
    # in their inbox keeps working unless it's expired
    def send_confirmation_email(signup)
      return false if signup.likely_spam || signup.email.blank? || signup.email_confirmed?
      return false if signup.email_confirmation_sent_at.to_i > (Time.current - CONFIRMATION_EMAIL_INTERVAL).to_i

      token = signup.email_confirmation_token_expired? ? SecurityTokenizer.new_token : signup.email_confirmation_token
      signup.update(email_confirmation_token: token, email_confirmation_sent_at: Time.current)
      EmailJobs::OrganizationSignupConfirmationJob.perform_async(signup.id)
      true
    end

    def confirmation_token_valid?(signup, token)
      return false if signup.email_confirmation_token_expired?

      Binxtils::Secure.compare?(token, signup.email_confirmation_token)
    end

    # Spends the token, so a forwarded email can't sign anyone in later
    def confirm_email!(signup)
      signup.update(email_confirmed_at: Time.current, email_confirmation_token: nil)
    end

    # The organization, with its errors if the name was taken since step 1 checked it
    def complete(signup, user:)
      organization = Organization.new(name: signup.name, kind: signup.kind, website: signup.website,
        auto_user_id: user.id, locations_attributes: [location_attributes(signup)])
      Organization.transaction do
        next unless organization.save

        OrganizationRole.create!(user:, organization:, role: "admin")
        signup.update!(organization:, creator: signup.creator || user)
      end
      return organization unless organization.persisted?

      AdminNotifier.new.for_organization(organization:, user:, type: "organization_created")
      organization
    end

    #
    # private below here
    #

    # What Organization's own validations would say about the name, before it's too late to fix
    def start_errors(signup)
      [(translation(:name_required) if signup.name.blank?),
        (translation(:kind_required) if signup.kind.blank?),
        (translation(:email_required) unless signup.email.to_s.match?(URI::MailTo::EMAIL_REGEXP)),
        *(name_errors(signup.name) if signup.name.present?)].compact
    end

    def name_errors(name)
      organization = Organization.new(name:)
      organization.valid?
      organization.errors.full_messages_for(:short_name) +
        (OrganizationNameValidator.valid?(name) ? [] : [translation(:name_unavailable)])
    end

    def location_attributes(signup)
      {name: signup.name, phone: signup.phone, publicly_visible: signup.publicly_visible,
       address_record_attributes: signup.address_record.attributes.slice(*AddressRecord.permitted_params.map(&:to_s))}
    end

    def translation(key) = I18n.t(key, scope: "shared.organization_signup")

    conceal :start_errors, :name_errors, :location_attributes, :translation
  end
end
