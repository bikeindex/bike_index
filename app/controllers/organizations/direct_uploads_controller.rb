# frozen_string_literal: true

module Organizations
  # The embed forms belong to the organization that hands them out, so their b_param's creator
  # is the organization's auto user rather than whoever fills the form in - the registration
  # flow's endpoint won't hand one over. The token in the form is what scopes the upload here,
  # exactly as it scopes the form itself.
  class DirectUploadsController < DirectUploads::BaseController
    prepend_before_action :require_registration

    private

    def b_param
      return @b_param if defined?(@b_param)

      @b_param = BParam.with_organization_or_no_creator(params[:b_param_token])
    end
  end
end
