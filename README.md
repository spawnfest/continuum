# Continuum

**TODO: Add description**

## Installation

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

## Features

* All-you-need (because you're not Google) Q in one dependency
* Core functionality:  queuing jobs and working jobs (FIFO and durable)
* Nice to haves
    * Retries
    * Dead letter Q (shareable?)
    * Transactional:  checkout, commit, rollback, timeout/acknowledge
    * Queues configurable in application tree
    * Limits (message size and queue length) and message lifetime?

## Strategy

* http://cr.yp.to/proto/maildir.html
* https://github.com/threez/file-queue/blob/master/lib/maildir.js

## API

* `purge()`

## TODO

* Build a Q data structure
* Managing processes
* Docs (this README)
* Stress test
* Example???  (soft realtime Twitter processing or whatever)

* Make init requeue
