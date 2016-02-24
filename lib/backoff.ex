defmodule Backoff do
  @moduledoc """
  Implements Exponential Backoff with Jitters according to this article:
    https://www.awsarchitectureblog.com/2015/03/backoff.html

  Specifically, we implement "Decorrelated Jitter" according to this pseudocode:
  ```
  temp = min(cap, base * 2 ** attempt)
  sleep = temp / 2 + random_between(0, temp / 2)
  sleep = min(cap, random_between(base, sleep * 3))
  ```

  """

  @type option :: %{max: pos_integer, base: pos_integer, attempt_max: pos_integer, delay_fn: fun}
  @type response :: {:ok, any} | {:error, any} | {:retry, any}
  # MAX = max # of ms
  #
  #@default_opts %{max: max # of ms, base: ms, max attempts}
  def default_opts do
    %{max: 300 * 1000,
      base: 100,
      attempt_max: 10,
       delay_fn: &sleep/1}
  end

  defp sleep(ms), do: :timer.sleep(ms)
  defp sleep_debug(ms) do
    IO.inspect "Sleeping for #{ms}"
    :timer.sleep(ms)
  end

  @doc """
  Takes a function that conforms to the following:
  @spec fn(none) :: {:ok | :error | :retry, any}

  Will retry, up to max when the return value is {:retry, any}. Otherwise, returns the value from executing fn.
  """
  @spec call(fun) :: response
  def call(f), do: call(f, 0, default_opts)

  @spec call(fun, option) :: response
  def call(f, opts), do: call(f, 0, Map.merge(default_opts, opts))

  def call(_, attempt, %{attempt_max: attempt_max}) when attempt >= attempt_max, do: {:error, :exceeded_max_retries}

  @spec call(fun, pos_integer, option) :: response
  def call(f, attempt, %{delay_fn: delay_fn} = opts) do
    result = f.()
    retry = fn ->
      ms = calculate_delay(attempt, opts)
      # TODO: make this configurable by passing in fn
      delay_fn.(ms)
      a = attempt + 1
      call(f, a, opts)
    end

    case result do
      {:ok, _} -> result
      {:error, _} -> result
      {:retry, _} -> retry.()
      _ -> {:ok, result}
    end
  end

  @doc """
  Decorrelated Jitter
  ```
  temp = min(cap, base * 2 ** attempt)
  sleep = temp / 2 + random_between(0, temp / 2)
  sleep = min(cap, random_between(base, sleep * 3))
  ```
  """
  def calculate_delay(attempt, %{max: max, base: base}) do
    # :math.pow(2, > 1024) blows up
    # And also yields ridiculously large numbers, ie
    # > 2.8e301
    capped_attempt = :erlang.min(1000, attempt)

    # Exponential backoff
    now = base * :math.pow(2, capped_attempt)
    # Cap at max time
    t = :erlang.min(max, now)
    # We need integers for :random.uniform and :timer
    t2 = round(t / 2)

    # Add jitters
    sleep = t2 + :random.uniform(t2)
    sleep = :random.uniform(sleep * 3) + base
    :erlang.min(max, sleep)
  end
end
