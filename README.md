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

At it's core, Continuum serializes queued messages into files and then moves 
those files from directory to directory as a means of changing status.  The 
atomic file move is the beating heart of this operation.  Uniquely generated 
file names based on timestamps and other criteria ensure that processing 
directories in order maintains FIFO semantics.  We can also track some details 
about attempted runs as a file moves through the system by appending flags to 
its name during a move.

We have placed a layer of processes on top of on top of these low-level data 
structures to provide niceties like minimal fuss worker pools.  Application code
transparently interacts with these processes to read and write from queues.

All systems have tradeoffs and ours is no different.  The dependency on a file 
system means this project is not useful with deployments to hosts with ephemeral
files that are frequently blown away.

Our processes design is also currently write constrained.  We've managed to 
reliably push 500 hundred messages a second, as you can see in the following 
image.

## Usage

### Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `continuum` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:continuum, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/continuum](https://hexdocs.pm/continuum).

### Configuration

FIXME

### Queueing and Processing Jobs

FIXME

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
