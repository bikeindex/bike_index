require 'spec_helper'
include PdfCreate
include RSpec::Matchers

describe PdfCreate do
  # TODO::Finish test for this module
  describe :pdf_format do
    let(:bike){ FactoryGirl.build :bike, name: "Some Random Name-#{rand(1000)}" }
    xit "should return a new pdf filename" do
    end
  end
    
end