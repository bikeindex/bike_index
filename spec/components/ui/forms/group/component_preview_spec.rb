# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Group::ComponentPreview, type: :request do
  let(:groups) { Lookbook.previews.find { it.preview_class == described_class }.scenarios.index_by(&:name) }
  let(:components) do
    Dir[Rails.root.join("app/components/ui/forms/**/component.rb")]
      .map { it.delete_prefix(Rails.root.join("app/components/ui/forms/").to_s).delete_suffix("/component.rb") }
      .reject { it.start_with?("legacy_form_well/") }
  end
  # Parts of a field, or not a field someone fills in. Input's kinds are checked instead of it
  let(:not_field_types) do
    %w[group input required_marker honeypot no_js_field nested_fields nested_fields/preview_fields
      combobox_manufacturer_options files/picker turnstile]
  end
  let(:field_types) { components - not_field_types }
  let(:validated_kinds) do
    UI::Forms::Input::Component::KIND_OPTIONS.filter_map { |kind, options| kind.to_s if options[:pattern] }
  end
  # What renders a field the browser checks the value of
  let(:validated_components) do
    field_types.select do |component|
      Dir[Rails.root.join("app/components/ui/forms/#{component}/component.{rb,html.erb}")].sum("") { File.read(it) }
        .match?(/kind: :(#{validated_kinds.join("|")})\b|type: "email"/)
    end
  end

  # The components and Input kinds a group's scenarios render themselves, not ones nested inside those
  def rendered_field_types(group)
    groups.fetch(group).scenarios.flat_map do |scenario|
      returned = described_class.new.public_send(scenario.name)
      source = scenario.source + File.read(Rails.root.join("app/components/#{returned[:template]}.html.erb"))
      source.scan(/UI::Forms::((?:\w+::)*\w+)::Component/).flatten.map(&:underscore) +
        source.scan(/kind: :(\w+)/).flatten + [returned.dig(:locals, :kind)&.to_s].compact
    end.uniq
  end

  it "shows every UI::Forms field, and every UI::Forms::Input kind, in All field types" do
    expect(not_field_types - components).to eq([])
    expect(rendered_field_types("all_field_types"))
      .to include(*field_types, *UI::Forms::Input::Component::KINDS.map(&:to_s))
  end

  it "shows every field with a frontend check in Validated" do
    expect(validated_kinds).to match_array(%w[telephone_field website_field postal_code_field])
    expect(validated_components).to match_array(%w[email address_group])
    expect(rendered_field_types("validated")).to include(*validated_kinds, *validated_components)
  end

  it "starts each Validated scenario with a checked field, and a submit to check it with" do
    groups.fetch("validated").scenarios.each do |scenario|
      get "/rails/view_components/ui/forms/group/component/#{scenario.name}"
      expect(response).to have_http_status(:ok)
      html = Nokogiri::HTML(response.body)
      expect(html.css("input[pattern][value], input[type='email'][value]")).to be_present, scenario.name
      expect(html.css("button[type='submit']")).to be_present, scenario.name
    end
  end
end
