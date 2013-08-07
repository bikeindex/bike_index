class Admin::BaseController < ApplicationController
  before_filter :require_superuser!
  layout "admin"
end
