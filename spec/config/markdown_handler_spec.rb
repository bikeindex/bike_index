require "rails_helper"

RSpec.describe MarkdownHandler do
  describe "rendering a .markdown template" do
    let(:rendered) { ApplicationController.render(inline: source, type: :markdown) }

    context "an ERB tag partway through" do
      let(:source) { "    POST <%= ENV[\"BASE_URL\"] %>/oauth/token\n\ntrailing paragraph\n" }
      it "renders the tag and everything after it" do
        expect(rendered).to match(%r{POST #{ENV["BASE_URL"]}/oauth/token})
        expect(rendered).to match("<p>trailing paragraph</p>")
      end
    end

    context "no ERB" do
      let(:source) { "# Heading\n\nA paragraph.\n" }
      it "renders the markdown" do
        expect(rendered).to match("<h1>Heading</h1>")
        expect(rendered).to match("<p>A paragraph.</p>")
      end
    end
  end
end
