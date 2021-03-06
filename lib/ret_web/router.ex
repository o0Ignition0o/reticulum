defmodule RetWeb.Router do
  use RetWeb, :router

  asset_hosts =
    "#{
      if Mix.env() == :dev do
        "http://hubs.dev:4000 https://hubs.dev:4000 http://hubs.dev:8080 https://hubs.dev:8080"
      end
    } https://assets-prod.reticulum.io https://smoke-assets-prod.reticulum.io https://assets-dev.reticulum.io https://smoke-assets-dev.reticulum.io https://asset-bundles-prod.reticulum.io https://smoke-asset-bundles-prod.reticulum.io https://asset-bundles-dev.reticulum.io https://smoke-asset-bundles-dev.reticulum.io"

  websocket_hosts =
    "#{
      if Mix.env() == :dev do
        "ws://hubs.dev:4000 wss://hubs.dev:4000 ws://hubs.dev:8080 wss://hubs.dev:8080"
      end
    } wss://prod.reticulum.io wss://smoke-prod.reticulum.io wss://dev.reticulum.io wss://smoke-dev.reticulum.io wss://prod-janus.reticulum.io wss://dev-janus.reticulum.io wss://hubs.social wss://hubs.mozilla.com wss://smoke-hubs.mozilla.com"

  pipeline :secure_headers do
    plug(
      SecureHeaders,
      secure_headers: [
        config: [
          content_security_policy:
            "default-src 'none'; script-src 'self' #{asset_hosts} https://cdn.rawgit.com https://aframe.io 'unsafe-eval'; font-src 'self' https://fonts.googleapis.com https://fonts.gstatic.com https://cdn.aframe.io #{
              asset_hosts
            }; style-src 'self' https://fonts.googleapis.com #{asset_hosts} 'unsafe-inline'; connect-src 'self' https://sentry.prod.mozaws.net #{
              asset_hosts
            } #{websocket_hosts} https://cdn.aframe.io https://www.mozilla.org data:; img-src 'self' #{asset_hosts} https://cdn.aframe.io data: blob:; media-src 'self' #{
              asset_hosts
            } data:; frame-src 'self'; frame-ancestors 'self'; base-uri 'none'; form-action 'self';",
          x_content_type_options: "nosniff",
          x_frame_options: "sameorigin",
          x_xss_protection: "1; mode=block",
          x_download_options: "noopen",
          x_permitted_cross_domain_policies: "master-only",
          strict_transport_security: "max-age=631138519"
        ]
      ]
    )
  end

  pipeline :ssl_only do
    plug(Plug.SSL, hsts: true, rewrite_on: [:x_forwarded_proto])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(JaSerializer.Deserializer)
  end

  pipeline :canonicalize_domain do
    plug(RetWeb.Plugs.RedirectToMainDomain)
  end

  pipeline :http_auth do
    plug(BasicAuth, use_config: {:ret, :basic_auth})
  end

  scope "/health", RetWeb do
    get("/", HealthController, :index)
  end

  scope "/api", RetWeb do
    pipe_through([:secure_headers, :api] ++ if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: []))

    scope "/v1", as: :api_v1 do
      resources("/hubs", Api.V1.HubController, only: [:create, :delete])
    end
  end

  scope "/", RetWeb do
    pipe_through(
      [:secure_headers, :browser] ++ if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    get("/*path", PageController, only: [:index])
  end
end
