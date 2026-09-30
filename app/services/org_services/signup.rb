# frozen_string_literal: true

# The organization signup flow (OrganizationSignupController). Everything waits on the
# OrganizationSignup until the emailed link proves the address - only then are the
# organization and its admin's account created, so an unconfirmed signup leaves nothing behind
module OrgServices
  module Signup
    extend Functionable

    CONFIRMATION_EMAIL_INTERVAL = 5.minutes
    STEPS = %w[1 2 finished].freeze

    # The session's signup, while it's still one - once its organization exists there's
    # nothing left to go back to
    def find(token)
      OrganizationSignup.unexpired.where(organization_id: nil).find_by(id_token: token) if token.present?
    end

    def start(user:, return_to: nil) = OrganizationSignup.create!(email: user&.email, return_to:)

    # What Pages::Register::Parts::Progress reads off a flow
    def steps = STEPS

    def position(step) = STEPS.index(step.to_s).to_i + 1

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
      signup.update(website:, phone:, publicly_visible: Binxtils::InputNormalizer.boolean(publicly_visible),
        address: address.to_h.stringify_keys.slice(*AddressRecord.permitted_params.map(&:to_s)).compact_blank)
      return true if signup.details_completed?

      signup.errors.add(:base, translation(:address_required))
      false
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
        signup.update!(organization:)
      end
      return organization unless organization.persisted?

      AdminNotifier.new.for_organization(organization:, user:, type: "organization_created")
      organization
    end

    #
    # private below here
    #

    # Checked here rather than left to complete, when it's too late to pick another name
    def start_errors(signup)
      [(translation(:name_required) if signup.name.blank?),
        (translation(:kind_required) if signup.kind.blank?),
        (translation(:email_required) unless signup.email.to_s.match?(User::EMAIL_REGEX)),
        (translation(:name_unavailable) if signup.name.present? && !Organization.name_available?(signup.name))].compact
    end

    def location_attributes(signup)
      {name: signup.name, phone: signup.phone, publicly_visible: signup.publicly_visible,
       address_record_attributes: signup.address}
    end

    def translation(key) = I18n.t(key, scope: "shared.organization_signup")

    conceal :start_errors, :location_attributes, :translation
  end
end
