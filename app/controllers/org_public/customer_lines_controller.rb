module OrgPublic
  class CustomerLinesController < OrgPublic::BaseController
    before_action :ensure_access_to_virtual_line!

    def show
    end
  end
end
