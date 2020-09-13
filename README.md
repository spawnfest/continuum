# Continuum

![Q from Star Trek](https://raw.githubusercontent.com/spawnfest/continuum/master/media/q.jpg)

_source [startrek.com](https://www.startrek.com/database_article/q-aliens)_

Continuum is a queueing system.

This library is intended to be a drop-it-in-and-you're-running dependency.  Step
one is **not** configuring an external database.  There's plenty of speed and 
features here to support many small and medium applications.  This is not 
intended to support Google level traffic, because you're probably not Google.

Continuum is a durable FIFO job queue.  Checking out jobs, clearing them on 
completion, and requeueing them on failure are supported.  Additional features
include:

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
    
We hope you enjoy it!

## Design

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

### Queueing and Processing Jobs

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

[James]()

## Strategy

* http://cr.yp.to/proto/maildir.html
* https://github.com/threez/file-queue/blob/master/lib/maildir.js
