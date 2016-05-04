=begin
*****************************************************************
* File: app/controllers/blogs_controller.rb 
* Name: Class BlogsController 
* Some methods to redirect user to a specific page
*****************************************************************
=end

class BlogsController < ApplicationController

  # Name: index
  # Explication: just a redirect method
  # Paramts:
  # Return: redirect user to new index of blogs page
  def index
    redirect_to news_index_url
  end
  
  # Name: show
  # Explication: just a redirect method
  # Paramts:
  # Return: redirect user to new show of blogs page
  def show
    redirect_to news_url
  end

end