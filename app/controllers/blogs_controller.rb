=begin
*****************************************************************
* File: app/controllers/blogs_controller.rb 
* Name: Class BlogsController 
* Some methods to redirect user to a specific page
*****************************************************************
=end

class BlogsController < ApplicationController

=begin    
  Name: index
  Explication: just a redirect method
  Paramts:
  Return: redirect user to new index of blogs page
=end
  
  def index
    redirect_to news_index_url
  end
 
=begin
  Name: show
  Explication: just a redirect method
  Params:
  Return: redirect user to new show of blogs page   
=end 
  
  def show
    redirect_to news_url
  end

end