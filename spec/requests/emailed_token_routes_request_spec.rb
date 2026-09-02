# frozen_string_literal: true

require "rails_helper"

# Emailed links have to be GETs, so each one lands on an interstitial that posts the token
# rather than spending it on the GET. A flow that loses its POST fails here.
RSpec.describe "emailed token routes", type: :request do
  let(:flows) do
    [
      {interstitial: "app/views/users/confirm_interstitial.html.haml",
       get_path: "/users/confirm", get_endpoint: "users#confirm",
       post_path: "/users/confirm", post_endpoint: "users#confirm", shared_component: true},
      {interstitial: "app/views/user_emails/confirm.html.haml",
       get_path: "/user_emails/1/confirm", get_endpoint: "user_emails#confirm",
       post_path: "/user_emails/1/confirm", post_endpoint: "user_emails#confirm", shared_component: true},
      {interstitial: "app/views/sessions/magic_link.html.haml",
       get_path: "/session/magic_link", get_endpoint: "sessions#magic_link",
       post_path: "/session/sign_in_with_magic_link", post_endpoint: "sessions#sign_in_with_magic_link",
       shared_component: true},
      {interstitial: "app/views/users/unsubscribe.html.haml",
       get_path: "/users/1/unsubscribe", get_endpoint: "users#unsubscribe",
       post_path: "/users/1/unsubscribe_update", post_endpoint: "users#unsubscribe_update",
       shared_component: true},
      {interstitial: "app/components/pages/register/step_confirm/component.html.erb",
       get_path: "/register/confirm", get_endpoint: "register#confirm",
       post_path: "/register/confirm_email", post_endpoint: "register#confirm_email",
       shared_component: false}
    ]
  end

  def endpoint(path, method)
    route = Rails.application.routes.recognize_path(path, method:)
    "#{route[:controller]}##{route[:action]}"
  rescue ActionController::RoutingError
    "not routable"
  end

  def interstitials_where(key)
    flows.select { |flow| flow[key] }.map { |flow| flow[:interstitial] }
  end

  # Includes .rb, so a component rendering from `call` counts. The shared component's own
  # files name it without being callers
  let(:app_sources) do
    Dir.glob(Rails.root.join("app/**/*.{rb,haml,erb}"))
      .to_h { |file| [Pathname.new(file).relative_path_from(Rails.root).to_s, File.read(file)] }
      .reject { |path, _| path.start_with?("app/components/pages/sessions/sign_in_interstitial/") }
  end

  def templates_matching(pattern)
    app_sources.select { |_path, source| source.match?(pattern) }.keys
  end

  # What actually renders an emailed link's form: each flow's own template, plus the shared
  # component it delegates to. Other forms submit themselves for good reasons, so only these
  # are held to waiting for a click
  def emailed_form_sources
    paths = flows.map { |flow| flow[:interstitial] } +
      Dir.glob(Rails.root.join("app/components/pages/sessions/sign_in_interstitial/*.{rb,erb}"))
        .map { |file| Pathname.new(file).relative_path_from(Rails.root).to_s }
    paths.uniq.reject { |path| path.end_with?("component_preview.rb") }
  end

  it "routes the emailed GET and the POST its interstitial submits, for every flow" do
    recognized = flows.to_h do |flow|
      [flow[:interstitial], {get: endpoint(flow[:get_path], :get), post: endpoint(flow[:post_path], :post)}]
    end
    target = flows.to_h do |flow|
      [flow[:interstitial], {get: flow[:get_endpoint], post: flow[:post_endpoint]}]
    end
    expect(recognized).to eq target
  end

  # Separate, so a routing regression doesn't mask these
  it "knows every template rendering the shared interstitial" do
    expect(templates_matching(/Pages::Sessions::SignInInterstitial::Component/))
      .to match_array interstitials_where(:shared_component)
  end

  # Scanners run the page's JS, so submitting on render hands them the action
  it "leaves every emailed-link form for the reader to submit" do
    submitting = emailed_form_sources.select do |path|
      File.read(Rails.root.join(path)).match?(/auto.submit|requestSubmit|data-controller/)
    end
    expect(submitting).to eq []
  end
end
