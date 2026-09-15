# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::FileUploadMulti::Component, type: :component do
  let(:options) { {} }
  let(:component) do
    render_inline(described_class.new(url: "/public_images", file_param: "file", **options)) { "<li>already stored</li>".html_safe }
  end

  it "renders the picker, the drop frame and the list of what's already stored" do
    expect(component).to have_css("[data-controller='ui--forms--file-upload-multi']")
    expect(component).to have_css("[data-ui--forms--file-upload-multi-url-value='/public_images']")
    expect(component).to have_css("input[type='file'][multiple][data-ui--forms--file-upload-multi-target='input']")
    expect(component).to have_css("label", text: "Upload")
    # decorative -- the label text is what names it
    expect(component).to have_css("label svg[aria-hidden='true']")
    expect(component).to have_css("ul[data-ui--forms--file-upload-multi-target='list'] li", text: "already stored")
    # each upload gets a row here, so it announces without the list moving focus
    expect(component).to have_css("ul[aria-live='polite'][data-ui--forms--file-upload-multi-target='status']")
    # nothing submits the input -- the controller reads its files and posts them itself
    expect(component).to have_no_css("input[type='file'][name]")
    expect(component).to have_no_css("input[type='file'][accept]")
  end

  describe "params" do
    let(:options) { {params: {blog_id: 12}} }

    it "posts them alongside the file" do
      expect(component).to have_css("[data-ui--forms--file-upload-multi-params-value='{\"blog_id\":12}']")
      expect(component).to have_css("[data-ui--forms--file-upload-multi-file-param-value='file']")
    end
  end

  describe "list_html_options" do
    let(:options) { {list_html_options: {id: "public_images", class: "row", data: {order_url: "/public_images/order"}}} }

    it "keeps the target the component wires alongside them" do
      expect(component).to have_css("ul#public_images.row[data-order-url='/public_images/order']" \
        "[data-ui--forms--file-upload-multi-target='list']")
    end
  end

  it "accepts a string, an array, or nothing" do
    expect(render_inline(described_class.new(url: "/x", file_param: "f", accept: "image/png,image/jpeg")))
      .to have_css("input[type='file'][accept='image/png,image/jpeg']")
    expect(render_inline(described_class.new(url: "/x", file_param: "f", accept: %w[.png .jpg])))
      .to have_css("input[type='file'][accept='.png,.jpg']")
  end

  # Two on a page would otherwise hand both labels the same input
  it "gives the input an id of its own, which its label points at" do
    ids = 2.times.map { render_inline(described_class.new(url: "/x", file_param: "f")).css("input[type=file]").first["id"] }

    expect(ids.uniq.count).to eq 2
    expect(component).to have_css("label[for='#{component.css("input[type=file]").first["id"]}']")
  end
end
