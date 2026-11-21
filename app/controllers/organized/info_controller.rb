module Organized
  class InfoController < Organized::BaseController
    # Organization signup's fetched submission redirects here
    before_action :force_html_response

    def show
      render Pages::Org::Info::Show::Component.new(organization: current_organization, current_user:,
        return_to: local_return_to)
    end
  end
end
