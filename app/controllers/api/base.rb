module API
  class Base < Grape::API
    mount API::V2::Root
  end
end