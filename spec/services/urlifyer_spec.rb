require "rails_helper"

RSpec.describe Urlifyer do
  describe "urlify" do
    it "does nothing if no website is present" do
      website = Urlifyer.urlify(nil)
      expect(website).to be_nil
      website = Urlifyer.urlify("  ")
      expect(website).to be_nil
      website = Urlifyer.urlify("i")
      expect(website).to be_nil
    end

    it "adds http:// if the website doesn't have it" do
      website = Urlifyer.urlify("www.somafab.com")
      expect(website).to eq("http://www.somafab.com")
    end

    it "doesn't do anything if the site has https://" do
      website = Urlifyer.urlify("http://www.somafab.com")
      expect(website).to eq("http://www.somafab.com")
    end

    it "doesn't let you do sweet XSS because http is present in the string" do
      website = Urlifyer.urlify('javascript://alert("XSS Payload")//http://')
      expect(website).to match(/\Ahttp:\/\//)
    end
  end

  describe "display" do
    let(:url) { "https://twitter.com/stolenbikessfo/status/537025628319805443" }

    it "strips the scheme and www, keeping the path" do
      expect(Urlifyer.display(url)).to eq "twitter.com/stolenbikessfo/status/537025628319805443"
      expect(Urlifyer.display(" HTTP://www.somafab.com/about?a=b ")).to eq "somafab.com/about?a=b"
      expect(Urlifyer.display("somafab.com/www.other")).to eq "somafab.com/www.other"
      expect(Urlifyer.display("https://other.com/https://somafab.com")).to eq "other.com/https://somafab.com"
    end

    it "truncates to the length, omission included" do
      expect(Urlifyer.display(url, length: 41)).to eq "twitter.com/stolenbikessfo/status/5370..."
      expect(Urlifyer.display("https://somafab.com", length: 41)).to eq "somafab.com"
    end

    it "is nil for a blank url" do
      expect(Urlifyer.display(nil)).to be_nil
      expect(Urlifyer.display("  ", length: 41)).to be_nil
    end
  end
end
