=begin
*****************************************************************
* File: app/controllers/blogs_controller.rb 
* Name: Class BlogsController 
* Some methods to redirect user to a specific page
*****************************************************************
=end

class BlogsController < ApplicationController

  def index
    redirect_to news_index_url
  end
  
  def show
    redirect_to news_url
  end

end