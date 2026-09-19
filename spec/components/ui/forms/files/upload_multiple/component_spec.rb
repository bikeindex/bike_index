# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Files::UploadMultiple::Component, type: :component do
  let(:options) { {} }
  let(:component) do
    render_inline(described_class.new(url: "/public_images", file_param: "file", **options)) { "<li>already stored</li>".html_safe }
  end

  it "renders what's already stored as the list, and a status for each upload below the picker" do
    expect(component).to have_css("ul[data-ui--forms--files--picker-target='list'] li", text: "already stored")
    # each upload gets a row here, so it announces without the list moving focus
    expect(component).to have_css("ul[aria-live='polite'][data-ui--forms--files--picker-target='status']")
    # nothing submits the input -- the controller reads its files and posts them itself
    expect(component).to have_css("input[type='file'][multiple]:not([name])")
  end

  describe "params" do
    let(:options) { {params: {blog_id: 12}} }

    it "posts them alongside the file" do
      expect(component).to have_css("[data-ui--forms--files--picker-params-value='{\"blog_id\":12}']")
      expect(component).to have_css("[data-ui--forms--files--picker-file-param-value='file']")
    end
  end

  describe "list_html_options" do
    let(:options) { {list_html_options: {id: "public_images", class: "row", data: {order_url: "/public_images/order"}}} }

    it "keeps the target the component wires alongside them" do
      expect(component).to have_css("ul#public_images.row[data-order-url='/public_images/order']" \
        "[data-ui--forms--files--picker-target='list']")
    end
  end

  it "gives the input an id of its own, which its label points at" do
    ids = 2.times.map { render_inline(described_class.new(url: "/x", file_param: "f")).css("input[type=file]").first["id"] }

    expect(ids.uniq.count).to eq 2
    expect(component).to have_css("label[for='#{component.css("input[type=file]").first["id"]}']")
  end
end
