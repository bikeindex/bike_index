# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module MailchimpData
        class Component < ApplicationComponent
          def initialize(user:)
            @user = user
            @mailchimp_datum = user.mailchimp_datum
          end
        end
      end
    end
  end
end
