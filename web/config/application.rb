require_relative "boot"

require "rails"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "active_job/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module CocinaWeb
  class Application < Rails::Application
    config.load_defaults 8.0

    # Autoload lib/cocina
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "UTC"
    config.i18n.default_locale = :en

    # Use async adapter for jobs in development (no Redis/DB needed)
    config.active_job.queue_adapter = :async
  end
end
