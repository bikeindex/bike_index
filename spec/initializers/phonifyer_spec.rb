# encoding: utf-8
require 'spec_helper'

describe Phonifyer do
  describe :phonify do 
    it "should strip and remove non digits" do
      number = Phonifyer.phonify("(999) 899 - 999")
      number.should eq("999899999")
    end
    it "shouldn't remove the country code" do
      number = Phonifyer.phonify("+91 80 4150 5583")
      number.should eq("+91 8041505583")
    end
  end
end