# Using EctoMorph to create a has_one_of association

So what do I mean by `has_one_of`? Well sometimes when modeling data we want to say something like "this thing can be one of these types of things". That is to say, our thing can be one of a group of possibilities, and can only be one of those at any one time. Why is this a useful way to talk about data? Isn't that just a has_one anyway? Let's look at an example to see...

We want to track athletes and their results in different events. To begin with we decide to have athletes, who have_one medal. The schemas would look like this:

```elixir
defmodule Athlete do
  use Ecto.Schema

  schema "athletes" do
    field(:name, :string)
    has_one(:medal, Medal)
  end
end

defmodule Medal do
  use Ecto.Schema

  schema "medals" do
    field(:type, :string)
    field(:championship_points_earned, :integer)
    belongs_to(:athlete, Athlete)
  end
end
```

This is great because we can have multiple rows in the medals table, each with a different `type`, with values like `gold`, `silver`, or `bronze`. Then our athlete can `has_one` Medal, whose specific type is `bronze`, for example.

This works for a while but then the athletics foundation announces they will no longer award medals for race wins, instead they will give prize money. What can we do to track this in our program? Crucially we need to be sure that we don't lose any existing data, so any athletes that already have medals still have medals.

We could create a new table called something like "prizes" which could have fields like "rank" and "amount". This captures the data we need to track the athletes, but isn't particularly appealing. To understand why let's look at what our schemas would look like:

```elixir
defmodule Athlete do
  use Ecto.Schema

  schema "athletes" do
    field(:name, :string)
    has_one(:medal, Medal)
    has_one(:prize, Prize)
  end
end

defmodule Medal do
  use Ecto.Schema

  schema "medals" do
    field(:type, :string)
    field(:championship_points_earned, :integer)
    belongs_to(:athlete, Athlete)
  end
end

defmodule Prize do
  use Ecto.Schema

  schema "prizes" do
    field(:rank, :integer)
    field(:amount, :integer)
    belongs_to(:athlete, Athlete)
  end
end
```

Whilst this works, there are a few things I don't like. Every athlete that won a medal will now have a null `Prize` relation just hanging around. Similarly, every new athlete that enters a race will have a null `Medal` relation just hanging around forever. This might be tolerable for one field, but what if the prize for winning changes again? Instead of a `Prize` or `Medal` the top finishers from now on get `AmazonVouchers`. Then we'd have _two_ legacy relations just hanging around forever.

The problem is the schema is not accurately representing our domain. An athlete cannot both win a medal AND prize money but there is nothing in our schema that prevents an athlete having both a `Prize` and a `Medal`. This isn't just about an academic sense of purity in the domain model, these kinds of problems can dramatically increase the complexity of the application code. If we want to query an athlete's winnings we need to know which key to look at:

```elixir
def winnings(athlete = %Athlete{prize: nil}) do
  athlete.medal
end

def winnings(athlete = %Athlete{medal: nil}) do
  athlete.prize
end
```

It gets even worse if we want to start validating in the application layer the creation of `Athlete`s so that you cannot have both a `medal` and a `prize`.

So can we do better? Can we move away from violating the tell don't ask principle and move towards a better domain model? Yes. The relationship we want is `has_on_of`. We want to be able to say that an Athlete's winnings are one of a set of possible things. Can we do that in Ecto? Yes it is possible, but it's a bit out of left field. The key is to notice that medals and prize money are two types of a more generic thing. We could call it a `Reward` for now. The approach we are going to take is to add a jsonb `reward` column to the `athletes` table, and let that be a custom ecto type which decides what specific reward we have. Let's step through the code to see what that would look like. First our Athlete schema will now look something like this:

```elixir
defmodule Athlete do
  use Ecto.Schema

  schema "athletes" do
    field(:name, :string)
    field(:reward, CustomTypes.Reward)
  end
end

defmodule Medal do
  use Ecto.Schema

  embedded_schema do
    field(:colour, :string)
  end
end

defmodule Prize do
  use Ecto.Schema

  embedded_schema do
    field(:rank, :string)
    field(:amount, :integer)
  end
end
```

Our `Medal` and `Prize` schemas have become embedded schemas. Our reward column will be a glob of json, so our Ecto type will do two things. It will take one of the reward schemas - i.e. `Medal` or `Prize` - and turn it into json so that we can put it in the jsonb column, and it will take any json that is in the reward column and serialize it into one of the relevant structs. Let's take a look at that:

```elixir
defmodule Reward do
  @behaviour Ecto.Type

  @impl true
  @doc "Returns the underlying type of a scenario"
  def type, do: :map

  @doc "Casts data retrieved from the DB into the correct struct"
  @impl true
  def cast(reward = %{"amount" => amount}) do
    {:ok, EctoMorph.to_struct(reward, PrizeMoney)}
  end

  def cast(reward = %{"colour" => colour}) do
    {:ok, EctoMorph.to_struct(reward, Medal)}
  end

  def cast(reward) do
    {:error, "Reward type #{inspect(reward)} is not supported"}
  end

  @impl true
  @doc """
  Because the rewards are embedded types, they do not use [dump/1](https://hexdocs.pm/ecto/Ecto.Type.html#c:dump/1)
  when saving rules into the db. Instead our [JSON lib](https://hexdocs.pm/jason/) handles that.
  """
  def dump(_), do: raise("This will never be called")

  @impl true
  @doc """
  Because the rewards are embedded types, they do not use [load/1](https://hexdocs.pm/ecto/Ecto.Type.html#c:load/1)
  when saving rewards into the db. Instead our [JSON lib](https://hexdocs.pm/jason/) handles that.
  """
  def load(_), do: raise("This will never be called")
end
```

The important function here is the `cast`. Think of this as the function that takes the json from the jsonb column and turns it into an Elixir struct. We use pattern matching to decide what to do with the glob of json, relying on the fact that if it were a `Medal` it would have a `colour` field, and if it were a `PrizeMoney` it would have an `amount` field. Once we know that we can use `EctoMorph` to build the correct struct. And voila!

So what would querying for a reward look like now?

```elixir
athlete = Repo.get(Athlete, 10)
# There's no need to preload the relation, or do a join as its all in one column
athlete.reward
```

Easy! And how about adding a new type of reward. Well first we would define the schema, let's pretend athletes now win discount vouchers for sporting goods. We first define the reward:

```elixir
defmodule DiscountVouchers do
  use Ecto.Schema

  embedded_schema do
    field(:percentage_discount, :decimal)
  end
end
```

Then handle the new case in the custom Ecto type's `cast` function:

```elixir
  @doc "Casts data retrieved from the DB into the correct struct"
  @impl true
  def cast(reward = %{"amount" => _}), do: {:ok, EctoMorph.to_struct(reward, PrizeMoney)}
  def cast(reward = %{"colour" => _}), do: {:ok, EctoMorph.to_struct(reward, Medal)}
  def cast(reward = %{"percentage_discount" => _}), do: {:ok, EctoMorph.to_struct(reward, DiscountVouchers)}

  def cast(reward) do
    {:error, "Reward type #{inspect(reward)} is not supported"}
  end
```

And that's it. What's really nice about this is if we want to do something with each reward, like say we want to calculate each reward's \$ value, we can use a protocol and define the specific conversion for each type cleanly.

```elixir
defprotocol DollarValue do
  def for(reward)
end

defimpl DollarValue, for: Medal do
  def for(medal = %{colour: "GOLD"}) do
    1_000_000
  end

  def for(medal = %{colour: "SILVER"}) do
    100_000
  end

  def for(medal = %{colour: "BRONZE"}) do
    10_000
  end
end

defimpl DollarValue, for: Prize do
  def for(%{amonunt: amount}), do: amount
end
```

Then use it like this:

```elixir
DollarValue.for(athlete.reward)
```

Pure unadulterated polymorphism. Yum!
