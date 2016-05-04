=begin
*****************************************************************
* File: app/controllers/blogs_controller.rb 
* Name: Class BlogsController 
* Some methods to redirect user to a specific page
*****************************************************************
=end

class BlogsController < ApplicationController

  # Name: index
  # Explication:
  # Paramts:
  # Return:
  def index
    redirect_to news_index_url
  end
  
  # Name: show
  # Explication:
  # Paramts:
  # Return:
  def show
    redirect_to news_url
  end

end