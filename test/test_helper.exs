Code.require_file(Path.expand("support/helper_modules.exs", __DIR__))

ExUnit.start(formatters: [ExUnit.PrideFormatter])
