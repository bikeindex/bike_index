# frozen_string_literal: true

# Accounts for people who proved an email address without ever choosing a password -
# a passwordless organization's members, and registrants following a confirmation link
module UserServices
  module PasswordlessCreator
    extend Functionable

    def find_or_create(email)
      return nil if email.blank?

      User.fuzzy_confirmed_or_unconfirmed_email_find(email) || create_confirmed(email)
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
