=begin
*****************************************************************
* File: app/controllers/page_controller.rb 
* Name: Class PageController 
* Class that contain assert to redirect in errors case
*****************************************************************
=end

class PageController < ApplicationController

=begin
  Name: assert
  Params: none
  Explication: simple assert page with no layout
  Return: render layout 	
=end  
  def assert
  	render layout: false
  end
end
