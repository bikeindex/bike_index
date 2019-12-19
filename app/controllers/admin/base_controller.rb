class Admin::BaseController < ApplicationController
  before_action :require_index_admin!
  layout "admin"
end
