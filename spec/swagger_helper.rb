require "rails_helper"

RSpec.configure do |config|
  config.swagger_root = Rails.root.to_s + "/swagger"

  config.swagger_docs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Auto Repair API",
        version: "v1",
        description: "Backend API for auto repair shop management system"
      },
      paths: {},
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT"
          }
        },
        schemas: {}
      },
      servers: [
        { url: "http://localhost:3000", description: "Development" }
      ]
    }
  }

  config.swagger_format = :yaml
end
