# frozen_string_literal: true

# Accounts for people who never chose a password - a passwordless organization's
# members, and registrants following a confirmation link
module UserServices
  module PasswordlessCreator
    extend Functionable

    # Returns whether this call created them alongside the user - confirming saves
    # again, so previously_new_record? can't answer that by the time it returns
    def find_or_create(email)
      return [nil, false] if email.blank?

      existing = User.fuzzy_confirmed_or_unconfirmed_email_find(email)
      existing.present? ? [existing, false] : [create_confirmed(email), true]
    end

    #
    # private below here
    #

    def create_confirmed(email)
      # passwordless_user: set_calculated_attributes is what gives them a digest
      user = User.new(skip_update: true, passwordless_user: true, email:)
      user.save!
      user.confirm(user.confirmation_token)
      user
    end

    conceal :create_confirmed
  end
end
