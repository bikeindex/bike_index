# encoding: utf-8
require 'spec_helper'

describe Urlifyer do
  describe 'urlify' do
    it 'does nothing if no website is present' do
      website = Urlifyer.urlify(nil)
      expect(website).to be_nil
      website = Urlifyer.urlify('i')
      expect(website).to be_nil
    end

    it "adds http:// if the website doesn't have it" do
      website = Urlifyer.urlify('www.somafab.com')
      expect(website).to eq('http://www.somafab.com')
    end

    it "doesn't do anything if the site has https://" do
      website = Urlifyer.urlify('http://www.somafab.com')
      expect(website).to eq('http://www.somafab.com')
    end

    it "doesn't let you do sweet XSS because http is present in the string" do
      website = Urlifyer.urlify('javascript://alert("XSS Payload")//http://')
      expect(website).to match(/\Ahttp:\/\//)
    end
  end
end
