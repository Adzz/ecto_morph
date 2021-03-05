# EctoMorph

EctoMorph morphs your Ecto capabilities into the s t r a t o s p h e r e !

Parse incoming data into custom structs, then validate it.

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
data = %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
EctoMorph.cast_to_struct(data, Test)

# or
data = %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
EctoMorph.cast_to_struct(data, Test, [:thing, embed: [:bar]])

# The data can also be a struct so this would work:
data = %Test{thing: "foo", embed: %Embed{bar: "baz"}}
EctoMorph.cast_to_struct(data, Test, [:thing, embed: [:bar]])

# So would this:
data = %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
EctoMorph.cast_to_struct(data, %Test{}, [:thing, embed: [:bar]])

# Changes can even be a different struct, if it 
# has overlapping keys they will be casted as expected:

defmoule OtherStruct do
  defstruct [:thing, :embed]
end

data = %OtherStruct{thing: "foo", embed: %{"bar"=> "baz"}}
EctoMorph.cast_to_struct(data, %Test{}, [:thing, embed: [:bar]])
```

Or something like this:

```elixir
with {:ok, %{status: 200, body: body}} <- HTTPoison.get("mygreatapi.co.uk") do
  EctoMorph.cast_to_struct(Jason.decode!(body), User)
end
```

We can also whitelist fields to cast / update:

```elixir
data = %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
EctoMorph.cast_to_struct(data, Test, [:thing])

data = %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
EctoMorph.cast_to_struct(data, Test, [:thing, embed: [:bar]])
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
(
  %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
  |> EctoMorph.generate_changeset(Test, [:thing])
  |> Ecto.Changeset.validate_required([:thing])
  |> EctoMorph.into_struct()
)

# or
(
  %{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
  |> EctoMorph.generate_changeset(Test, [:thing])
  |> Ecto.Changeset.validate_change(...)
  |> Repo.insert!
)
```

### Valiating Nested Changesets

Easily the coolest feature, say you have nested changesets via embeds or has_one/many, you can now specify a path to a changeset and specify a validation function for the changeset(s) at the end of that path. If your path ends at a list of changesets (because your model has a has_many relation for example), each of those changesets will be validated.

```elixir
%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}
|> EctoMorph.generate_changeset(Test)
|> EctoMorph.validate_nested_changeset([:embed], &MyEmbed.validate/1)

# or
json = %{
  "has_many" => [
    %{"steamed_hams" => [%{"pickles" => 1}, %{"pickles" => 2}]},
    %{"steamed_hams" => [%{"pickles" => 1}]},
    %{"steamed_hams" => [%{"pickles" => 4}, %{"pickles" => 5}]}
  ]
}

# Here each of the steamed_hams above will have their pickle count validated:

EctoMorph.generate_changeset(json, MySchema)
|> EctoMorph.validate_nested_changeset([:has_many, :steamed_hams], fn changeset ->
  Ecto.Changeset.validate_number(changeset, :pickles, greater_than: 3)
end)
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

EctoMorph.filter_by_schema_fields(%{random: "data", more: "fields"}, Test)
%{random: "data"}
```

You can even deep filter:

```elixir

defmodule OtherThing do
  use Ecto.Schema
  @primary_key false
  embedded_schema do
    field(:id, :integer)
  end
end

defmodule Test do
  use Ecto.Schema

  embedded_schema do
    field(:random, :string)
    embeds_one(:other_thing, OtherThing)
  end
end

data = %{
  random: "data",
  more: "fields",
  __meta__: "stuff", 
  other_thing: %{id: 1, ignored: "field"}
}

EctoMorph.deep_filter_by_schema_fields(data, Test)
%{random: "data", other_thing: %{id: 1}}
```

Check out the [docs](https://hexdocs.pm/ecto_morph) for more examples and specifics

## Installation

[available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_morph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_morph, "~> 0.1.22"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_morph](https://hexdocs.pm/ecto_morph).
