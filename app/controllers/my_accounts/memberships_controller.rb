module MyAccounts
  class MembershipsController < ApplicationController
    include Sessionable

    before_action :authenticate_user_for_my_accounts_controller

    def show
      render(Pages::MyAccount::Memberships::Show::Component.new(membership: current_user.membership_active))
    end
  end
end
