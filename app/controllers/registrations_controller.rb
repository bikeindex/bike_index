class RegistrationsController < ApplicationController
  # before_filter :find_b_param, only: [:edit, :update]
  # before_filter :ensure_user_allowed_to_edit, only: [:edit, :update]
  layout 'application_revised'

  def new # Attributes assigned in the partial so it can be used anywhere
  end
end