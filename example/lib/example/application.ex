defmodule Example.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    root_dir = Path.join([:code.priv_dir(:example), "queues"])

    children = [
      # Start the Telemetry supervisor
      ExampleWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Example.PubSub},
      # Start the Endpoint (http/https)
      ExampleWeb.Endpoint,
      # Start a worker by calling: Example.Worker.start_link(arg)
      # {Example.Worker, arg}
      {
        Continuum.Q,
        [
          name: DeadLetterQueue,
          workers: 1,
          function: &dead_example/1,
          root_dir: root_dir
        ] = dead_letters
      },
      {
        Continuum.Q,
        name: ExampleQueue,
        workers: 1,
        function: &example/1,
        root_dir: root_dir,
        dead_letters: dead_letters
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def example(arg) do
    :timer.sleep(1_000)
    arg
  end

  def dead_example(arg) do
    :timer.sleep(1_000)
    arg
  end
end
