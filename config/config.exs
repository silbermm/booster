# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :booster, BoosterWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "0rWYR5Pp2SxjgStrTsckBiFWWLqRfXMXjqdccXKj8OxwTrNf5KLFzpSsM2yoosxJ",
  render_errors: [view: BoosterWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Booster.PubSub,
  live_view: [signing_salt: "xt+hlKzr"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ex_aws,
  access_key_id: [{:awscli, "default", 30}, {:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [
    {:awscli, "default", 30},
    {:system, "AWS_SECRET_ACCESS_KEY"},
    :instance_role
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
