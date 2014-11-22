# encoding: utf-8
require 'spec_helper'

describe Urlifyer do
  describe :urlify do 
    it "does nothing if no website is present" do 
      website = Urlifyer.urlify(nil)
      website.should be_nil
      website = Urlifyer.urlify('i')
      website.should be_nil
    end

    it "adds http:// if the website doesn't have it" do 
      website = Urlifyer.urlify('www.somafab.com')
      website.should eq('http://www.somafab.com')
    end

    it "doesn't do anything if the site has https://" do 
      website = Urlifyer.urlify('http://www.somafab.com')
      website.should eq('http://www.somafab.com')
    end
  end
end