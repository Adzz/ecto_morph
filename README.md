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
EctoMorph.to_struct(%{"thing" => "foo", "embed" => %{"bar"=> "baz"}}, Test)
```

## Installation

[available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_morph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_morph, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_morph](https://hexdocs.pm/ecto_morph).
