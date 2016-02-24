# Backoff

**Library for Exponential Backoff with Correlated Jitters.**

## Installation

Install from master on GH, I'll post to hex if I keep working with this library.

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add backoff to your list of dependencies in `mix.exs`:

        def deps do
          [{:backoff, "~> 0.0.1"}]
        end

  2. Ensure backoff is started before your application:

        def application do
          [applications: [:backoff]]
        end
