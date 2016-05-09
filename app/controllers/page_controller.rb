class PageController < ApplicationController
  
# Name: assert
# Explication: simple assert page with no layout 
  def assert
  	render layout: false
  end
end
