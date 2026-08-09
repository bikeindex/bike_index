# frozen_string_literal: true

require "rails_helper"

# Emailed links have to be GETs, so each one lands on an interstitial that posts the token
# rather than spending it on the GET. A flow that loses its POST fails here.
RSpec.describe "emailed token routes", type: :request do
  let(:flows) do
    [
      {interstitial: "app/views/users/confirm_interstitial.html.haml",
       get_path: "/users/confirm", get_endpoint: "users#confirm",
       post_path: "/users/confirm", post_endpoint: "users#confirm",
       shared_component: true, auto_submit: false},
      {interstitial: "app/views/user_emails/confirm.html.haml",
       get_path: "/user_emails/1/confirm", get_endpoint: "user_emails#confirm",
       post_path: "/user_emails/1/confirm", post_endpoint: "user_emails#confirm",
       shared_component: true, auto_submit: false},
      {interstitial: "app/views/sessions/magic_link.html.haml",
       get_path: "/session/magic_link", get_endpoint: "sessions#magic_link",
       post_path: "/session/sign_in_with_magic_link", post_endpoint: "sessions#sign_in_with_magic_link",
       shared_component: true, auto_submit: false},
      {interstitial: "app/views/users/unsubscribe.html.haml",
       get_path: "/users/1/unsubscribe", get_endpoint: "users#unsubscribe",
       post_path: "/users/1/unsubscribe_update", post_endpoint: "users#unsubscribe_update",
       shared_component: true, auto_submit: true},
      {interstitial: "app/components/register/step_confirm/component.html.erb",
       get_path: "/register/confirm", get_endpoint: "register#confirm",
       post_path: "/register/confirm_email", post_endpoint: "register#confirm_email",
       shared_component: false, auto_submit: false}
    ]
  end

  def interstitials_where(key)
    flows.select { |flow| flow[key] }.map { |flow| flow[:interstitial] }
  end

  def endpoint(path, method)
    route = Rails.application.routes.recognize_path(path, method:)
    "#{route[:controller]}##{route[:action]}"
  rescue ActionController::RoutingError
    "not routable"
  end

  # Includes .rb, so a component that renders from `call` or a controller counts. The shared
  # component's own template wires the controller and its preview demos it - but component.rb
  # stays in scope, so flipping its default back to auto-submitting fails here
  let(:app_sources) do
    Dir.glob(Rails.root.join("app/**/*.{rb,haml,erb}"))
      .to_h { |file| [Pathname.new(file).relative_path_from(Rails.root).to_s, File.read(file)] }
      .except("app/components/sessions/sign_in_interstitial/component.html.erb",
        "app/components/sessions/sign_in_interstitial/component_preview.rb")
  end

  # The quotes around auto-submit keep prose about auto-submitting out of it
  def templates_matching(pattern)
    app_sources.select { |_path, source| source.match?(pattern) }.keys
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
    expect(templates_matching(/Sessions::SignInInterstitial::Component/))
      .to match_array interstitials_where(:shared_component)
  end

  # Scanners follow emailed links and run the page's JS, so a POST that spends its token has
  # to wait for a click. Only a POST that's safe to repeat may submit itself.
  it "auto submits only where the POST doesn't spend its token" do
    # Either asking the shared interstitial for it, or wiring the controller directly
    expect(templates_matching(/auto_submit: true|"auto-submit"/))
      .to match_array interstitials_where(:auto_submit)
  end
end
