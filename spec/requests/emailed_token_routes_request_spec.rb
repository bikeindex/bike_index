require "rails_helper"

# Emailed links have to be GETs, so each one lands on an interstitial that posts the token
# rather than spending it on the GET. A flow that loses its POST fails here.
RSpec.describe "emailed token routes", type: :request do
  let(:flows) do
    [
      {interstitial: "app/views/users/confirm_interstitial.html.haml",
       get_path: "/users/confirm", get_endpoint: "users#confirm",
       post_path: "/users/confirm", post_endpoint: "users#confirm"},
      {interstitial: "app/views/user_emails/confirm.html.haml",
       get_path: "/user_emails/1/confirm", get_endpoint: "user_emails#confirm",
       post_path: "/user_emails/1/confirm", post_endpoint: "user_emails#confirm"},
      {interstitial: "app/views/sessions/magic_link.html.haml",
       get_path: "/session/magic_link", get_endpoint: "sessions#magic_link",
       post_path: "/session/sign_in_with_magic_link", post_endpoint: "sessions#sign_in_with_magic_link"},
      {interstitial: "app/views/users/unsubscribe.html.haml",
       get_path: "/users/1/unsubscribe", get_endpoint: "users#unsubscribe",
       post_path: "/users/1/unsubscribe_update", post_endpoint: "users#unsubscribe_update"},
      {interstitial: "app/components/register/confirm/component.html.erb",
       get_path: "/register/confirm", get_endpoint: "register#confirm",
       post_path: "/register/confirm_email", post_endpoint: "register#confirm_email"}
    ]
  end

  def endpoint(path, method)
    route = Rails.application.routes.recognize_path(path, method:)
    "#{route[:controller]}##{route[:action]}"
  rescue ActionController::RoutingError
    "not routable"
  end

  # Every template that auto submits, minus the shared component's own markup
  def auto_submitting_templates
    Dir.glob(Rails.root.join("app/{views,components}/**/*.{haml,erb}"))
      .select { |file| File.read(file).match?(/SignInInterstitial|auto-submit/) }
      .map { |file| Pathname.new(file).relative_path_from(Rails.root).to_s }
      .reject { |path| path.start_with?("app/components/sessions/sign_in_interstitial/") }
  end

  it "routes the emailed GET and the POST its interstitial submits, for every flow" do
    recognized = flows.to_h do |flow|
      [flow[:interstitial], {get: endpoint(flow[:get_path], :get), post: endpoint(flow[:post_path], :post)}]
    end
    target = flows.to_h do |flow|
      [flow[:interstitial], {get: flow[:get_endpoint], post: flow[:post_endpoint]}]
    end
    expect(recognized).to eq target

    # A new auto submitting template means a new emailed token flow, which belongs above
    expect(auto_submitting_templates).to match_array flows.map { |flow| flow[:interstitial] }
  end
end
