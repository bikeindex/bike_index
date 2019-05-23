module Organized
  class AdminController < Organized::BaseController
    before_filter :ensure_admin!
    skip_before_filter :ensure_member!
    before_filter :ensure_not_ambassador_organization!
  end
end
