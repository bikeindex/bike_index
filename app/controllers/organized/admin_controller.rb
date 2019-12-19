module Organized
  class AdminController < Organized::BaseController
    before_action :ensure_admin!
    skip_before_action :ensure_member!
  end
end
