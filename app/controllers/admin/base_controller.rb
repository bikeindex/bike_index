=begin
*****************************************************************
* File: app/controllers/admin/base_controller.rb
* Name: Class Admin::BaseController
* 
*****************************************************************
=end

class Admin::BaseController < ApplicationController
  before_filter :require_index_admin!
  layout "admin"
end
