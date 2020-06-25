# EctoMorph

EctoMorph morphs your Ecto capabilities into the s t r a t o s p h e r e !

Usually you have to do something like this:

```elixir
defmodule Embed do
  use Ecto.Schema

  embedded_schema do
    field(:bar, :string)
  end
end

defmodule Test do
  use Ecto.Schema

  embedded_schema do
    field(:thing, :string)
    embeds_one(:embed, Embed)
  end

Ecto.Changeset.cast(%Test{}, %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}, [:thing])
|> Ecto.Changeset.cast_embed(:embed)
```

Now we can do this:

```elixir
EctoMorph.cast_to_struct(%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}, Test)

# or

EctoMorph.cast_to_struct(%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}, Test, [:thing, embed: [:bar]])

# The data can also be a struct so this would work:
EctoMorph.cast_to_struct(%Test{thing: "foo", embed: %Embed{bar: "baz"}}, Test, [:thing, embed: [:bar]])

# So would this:
EctoMorph.cast_to_struct(%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}, %Test{}, [:thing, embed: [:bar]])

# Changes can even be a different struct, if it has overlapping keys they will be casted as expected:

defmoule OtherStruct do
  defstruct [:thing, :embed]
end

EctoMorph.cast_to_struct(%OtherStruct{thing: "foo", embed: %{"bar"=> "baz"}}, %Test{}, [:thing, embed: [:bar]])
```

Or something like this:

```elixir
with {:ok, %{status: 200, body: body}} <- HTTPoison.get("mygreatapi.co.uk") do
  Jason.decode!(body)
  |> EctoMorph.cast_to_struct(User)
end
```

We can also whitelist fields to cast / update:

```elixir
EctoMorph.cast_to_struct(%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}, Test, [:thing])
EctoMorph.cast_to_struct(%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}, Test, [:thing, embed: [:bar]])
```

Sometimes it makes sense to update a struct we have retrieved from the database with data from our response. We can do that like so:

```elixir
def update(data) do
  # This will update the db struct with the data passed in, then update the db.
  MyRepo.get!(MySchema, 10)
  |> EctoMorph.update_struct(data)
  |> MyRepo.update!()
end
```

### Validations

Often you'll want to do some validations, that's easy:

```elixir
%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
|> EctoMorph.generate_changeset(Test, [:thing])
|> Ecto.Changeset.validate_required([:thing])
|> EctoMorph.into_struct()

# or 

%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
|> EctoMorph.generate_changeset(Test, [:thing])
|> Ecto.Changeset.validate_change(...)
|> Repo.insert!
```

Other abilities include creating a map from an ecto struct, dropping optional fields if you decide to:

```elixir
EctoMorph.map_from_struct(%Test{})
%{foo: "bar", updated_at: ~N[2000-01-01 23:00:07], inserted_at: ~N[2000-01-01 23:00:07], id: 10}

EctoMorph.map_from_struct(%Test{}, [:exclude_timestamps])
%{foo: "bar", id: 10}

EctoMorph.map_from_struct(%Test{}, [:exclude_timestamps, :exclude_id])
%{foo: "bar"}
```

and being able to filter some data by the fields in the given schema:

```elixir
defmodule Test do
  use Ecto.Schema

  embedded_schema do
    field(:random, :string)
  end
end

EctoMorph.filter_by_schema_fields(%{"random" => "data", "more" => "fields"}, Test)
%{"random" => "data"}
```

Check out the docs folder for more examples, table of contents below:

- [Casting data](https://github.com/Adzz/ecto_morph/blob/master/docs/casting_data.md)
- [Creating a has_one_of relation](https://github.com/Adzz/ecto_morph/blob/master/docs/has_one_of.md)

## Installation

[available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_morph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_morph, "~> 0.1.15"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_morph](https://hexdocs.pm/ecto_morph).
