class Admin::BaseController < ApplicationController
  before_filter :require_index_admin!
  layout "admin"
end
