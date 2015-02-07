module API
  class Dispatch < Grape::API
    mount API::V2::Root
    format :json
  end

  Base = Rack::Builder.new do
    use API::Logger
    run API::Dispatch
  end
end