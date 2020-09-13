defmodule Example.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    root_dir = Path.join([:code.priv_dir(:example), "queues"])

    queues = [
      [
        name: ExampleQueue,
        workers: 3,
        function: &example/1,
        root_dir: root_dir
      ],
      [
        name: SomeOtherQueue,
        workers: 3,
        function: &example/1,
        root_dir: root_dir
      ],
    ]

    dead_letters = [workers: 1, function: &dead_example/1]

    children =
      [
        ExampleWeb.Telemetry,
        {Phoenix.PubSub, name: Example.PubSub},
        ExampleWeb.Endpoint,
        {
          Example.StressTester,
          queues: [ExampleQueue, SomeOtherQueue]
        }

      ] ++
      Continuum.Q.build_with_dead_letters(queues, dead_letters)

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
    ms = Enum.random(1_000..2_999)
    :timer.sleep(ms)
    arg
  end

  def dead_example(arg) do
    :timer.sleep(1_000)
    arg
  end
end
