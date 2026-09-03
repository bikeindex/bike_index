require "rails_helper"

RSpec.describe RegistrationSequencePage, type: :model do
  describe "validations" do
    it "requires a title and at least one bullet" do
      page = FactoryBot.build(:registration_sequence_page, title: "", body: "")
      expect(page).to be_invalid
      expect(page.errors.attribute_names).to include(:title, :body)
    end

    it "rejects a body with no visible text" do
      page = FactoryBot.build(:registration_sequence_page, body: "<ul></ul>")
      expect(page).to be_invalid
      expect(page.errors[:body]).to be_present
    end

    it "accepts a title and a bulleted body" do
      expect(FactoryBot.build(:registration_sequence_page)).to be_valid
    end
  end

  describe "#sanitize_body" do
    let(:page) { FactoryBot.create(:registration_sequence_page, body:) }
    let(:body) { "<ul><li>one</li><li><b>two</b><script>alert(1)</script></li></ul>" }

    it "strips disallowed tags on save" do
      expect(page.body).to include("<li>one</li>")
      expect(page.body).to include("<b>two</b>")
      expect(page.body).to_not include("script")
    end

    context "blank body" do
      it "leaves nil alone" do
        page = FactoryBot.build(:registration_sequence_page, body: nil)
        page.valid?
        expect(page.body).to be_nil
      end
    end
  end

  describe "#heading_text" do
    let(:page) { FactoryBot.build(:registration_sequence_page, title: "Batteries & charging", heading:) }

    context "with a heading" do
      let(:heading) { "Looks like you have an e-vehicle!" }

      it "is the heading - the title labels the rules instead" do
        expect(page.heading_text).to eq "Looks like you have an e-vehicle!"
      end
    end

    context "without one" do
      let(:heading) { " " }

      it "falls back to the title" do
        expect(page.heading_text).to eq "Batteries & charging"
      end
    end
  end

  describe "#bullets" do
    let(:page) { FactoryBot.build(:registration_sequence_page, body:) }
    let(:body) { "<ul><li>one</li><li>and <em>two</em></li></ul>" }

    it "splits the body list into a rule each, keeping their markup" do
      expect(page.bullets).to eq ["one", "and <em>two</em>"]
    end

    context "body without a list" do
      let(:body) { "<p>just the one</p>" }

      it "is the whole body" do
        expect(page.bullets).to eq ["<p>just the one</p>"]
      end
    end

    context "blank body" do
      let(:body) { nil }

      it "is empty" do
        expect(page.bullets).to eq []
      end
    end
  end
end
