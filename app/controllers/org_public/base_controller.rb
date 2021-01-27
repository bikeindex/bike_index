module OrgPublic
  class BaseController < ApplicationController
    before_action :ensure_current_organization!
  end
end
