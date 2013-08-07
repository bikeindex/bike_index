require 'spec_helper'

describe SitemapsController do
 
  describe :index do
    it "should render the page" do 
      get :index, format: 'xml'
      response.code.should eql("200")
    end
  end

end

