module Organized
  class AdminController < Organized::BaseController
    before_filter :ensure_admin!
    skip_before_filter :ensure_member!
  end
end