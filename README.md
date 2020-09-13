# Continuum

![Q from Star Trek](https://raw.githubusercontent.com/spawnfest/continuum/master/media/q.jpg)

_source [startrek.com](https://www.startrek.com/database_article/q-aliens)_

Continuum is a queueing system.

This library is intended to be a drop-it-in-and-you're-running dependency.  Step
one is **not** configuring an external database.  There's plenty of speed and 
features here to support many small and medium applications.  This is not 
intended to support Google level traffic, because you're probably not Google.

Continuum is a durable FIFO (First In, First Out) job queue.  Checking out jobs,
clearing them on completion, and requeueing them on failure are supported.
Additional features include:

* Retries
* "Dead Letter" queueing
* Worker pools
* Telemetry metrics
* Configurable limits
    * Message size
    * Message lifetime
    * Queue length
    * Worker timeouts
    * Max retries
    
This project began life as a [Spawnfest 2020](https://spawnfest.github.io/) 
contest entry.  We hope you enjoy it!

## Design

We examined multiple strategies for building a queue on the file system, but 
settled for the "[maildir](http://cr.yp.to/proto/maildir.html)" strategies that 
have powered email for so long.

At its core, Continuum serializes queued messages into files and then moves 
those files from directory to directory as a means of changing status.  The 
atomic file move is the beating heart of this operation.  Uniquely generated 
file names, based on timestamps and other criteria, ensure that processing 
directories in order maintains FIFO semantics.  We can also track some details 
about attempted runs as a file moves through the system by appending flags to 
its name during a move.  This flow doesn't require the use of file locks.

We have placed a layer of processes on top of these low-level data structures 
to provide niceties like minimal fuss worker pools.  Application code 
transparently interacts with these processes to read and write from queues.

All systems have tradeoffs and ours is no different.  The dependency on a file 
system means this project is not useful with deployments to hosts with ephemeral
file system that are frequently blown away.

Our processes design is also currently write constrained.  We've managed to 
reliably push 500 hundred messages a second, as you can see in the following 
image.

![performance graphs](https://raw.githubusercontent.com/spawnfest/continuum/master/media/early_performance.png)

_To view these graphs on your own machine, start the Phoenix app in the 
`example/` directory and navigate to Live Dashboard, Metrics, then the Queue 
tab._

We could absolutely reduce this bottleneck with more effort.  The underlying 
data structures can support more volume, but doing so comes with new challenges 
and 500 messages a second meets plenty of needs!

## Usage

### Installation

Until this project is on Hex, you'll probably want to play with it from a local 
path with configuration like the following:

```elixir
def deps do
  [
    {:continuum, path: "../continuum"}
  ]
end
```

Or you can load it from [GitHub](https://github.com/spawnfest/continuum):

```elixir
def deps do
  [
    {:continuum, github: "spawnfest/continuum"}
  ]
end
```

### Configuration

You configure Continuum by asking it to add processes into your supervision 
tree.  The following example builds two queues with a shared "Dead Letter" 
queue:

```elixir
  def start(_type, _args) do
    root_dir = Path.join([:code.priv_dir(:example), "queues"])

    # setup your queues and their worker pools
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

    # setup "Dead Letter" workers
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
        Continuum.Q.build_with_dead_letters(queues, dead_letters)  # add queues!

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

### Queueing and Processing Jobs

You can queue jobs from anywhere with code like:

```elixir
Continuum.Q.push(QueueNameFromConfig, any_term_as_a_message)
```

You specify the number of `:workers` you want to run for each queue and a 
`:function` reference they should pass messages to for working in your config.
See the example config above.

## Team:  Irregular Apocalypse

We're a small team of friends who live in the same city near the center of the 
United States.

### Clayton Flesher

[Clayton](https://twitter.com/claytonflesher) served as the idea man and primary
stakeholder for this project.  He dreamed up our plan, kept our eyes on the time
limit, and changed our test output into rainbowy greatness.  This is important 
stuff!

### Paul Dawson

[Paul](https://twitter.com/piisalie) served as our resident security expert.
All attempts to add a few more bytes to a size limit or a few more seconds to a
timeout earned stern glances from him.  It's probably not his fault if your hard
drive melts.

### James Edward Gray II

[James](https://twitter.com/JEG2) spent a large portion of the contest waxing 
rhapsodic about atomic file operations and the glories of email.  It doesn't 
take a whole lot to amuse that guy.
