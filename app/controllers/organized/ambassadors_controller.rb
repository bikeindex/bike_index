module Organized
  class AmbassadorsController < Organized::BaseController
    def index
      @ambassadors = current_organization.users
      @tasks = []
    end
  end
end
