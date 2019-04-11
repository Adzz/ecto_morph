defmodule EctoMorph do
  @moduledoc """
  Utility functions for Ecto related stuff and things.
  """
  @typep ecto_struct :: Ecto.Schema.t()
  @typep ecto_schema_module :: atom()
  @typep map_with_string_keys :: %{required(String.t()) => any()}
  @doc """
  Takes some data and tries to convert it to a struct in the shape of the given schema. Casts values
  to the types defined by the schema dynamically using ecto changesets.

  Consider this:

      iex> Jason.encode!(%{a: :b, c: Decimal.new("10")}) |> Jason.decode!
      %{"a" => "b", "c" => "10"}

  When we decode some JSON (e.g. from a jsonb column in the db or from a network request), the JSON gets
  `decode`d by our Jason lib, but not all of the information is preserved; any atom keys become strings,
  and if the value is a type that is not part of the JSON spec, it is casted to a string.

  This means we cannot pass that JSON data directly into a struct/2 function and expect a shiny
  Ecto struct back (struct!/2 will just raise, and struct/2 will silently return an empty struct)

  UNTIL NOW!

  Here we take care of casting the values in the json to the type that the given schema
  defines, as well as turning the string keys into (existing) atoms. (We know they will be existing
  atoms because they will exist in the schema definitions.)

  We filter out any keys that are not defined in the schema.

  Check out the test for more full examples.

  ### Examples

      iex> defmodule Test do
      ...>   use Ecto.Schema
      ...>
      ...>   embedded_schema do
      ...>     field(:pageviews, :integer)
      ...>   end
      ...> end
      ...> {:ok, test = %Test{}} = to_struct(%{"pageviews" => "10"}, Test)
      ...> test.pageviews
      10

      iex> defmodule Test do
      ...>   use Ecto.Schema
      ...>
      ...>   embedded_schema do
      ...>     field(:pageviews, :integer)
      ...>   end
      ...> end
      ...> json = %{"pageviews" => "10", "ignored_field" => "ten"}
      ...> {:ok, test = %Test{}} = to_struct(json, Test)
      ...> test.pageviews
      10
  """
  @spec to_struct(map_with_string_keys, ecto_schema_module) ::
          {:ok, ecto_struct} | {:error, Ecto.Changeset.t()}
  def to_struct(data, schema) do
    generate_changeset(data, schema)
    |> make_struct()
  end

  def generate_changeset(data, schema) do
    with [] <- embedded_schema_fields(schema) do
      schema
      |> struct(%{})
      |> Ecto.Changeset.cast(data, schema.__schema__(:fields))
    else
      embedded_fields ->
        schema
        |> struct(%{})
        |> Ecto.Changeset.cast(data, non_embedded_schema_fields(schema))
        |> cast_all_the_embeds(embedded_fields)
    end
  end

  defp cast_all_the_embeds(changeset, embedded_fields) do
    Enum.reduce(embedded_fields, changeset, fn embedded_field, changeset ->
      Ecto.Changeset.cast_embed(changeset, embedded_field,
        with: fn struct, changes ->
          generate_changeset(changes, struct.__struct__)
        end
      )
    end)
  end

  defp make_struct(changeset = %{errors: []}) do
    {:ok, Ecto.Changeset.apply_changes(changeset)}
  end

  defp make_struct(changeset) do
    {:error, changeset}
  end

  def embedded_schema_fields(schema) do
    Enum.filter(schema.__schema__(:fields), fn field ->
      with {:embed, _} <- schema.__schema__(:type, field) do
        true
      else
        _ -> false
      end
    end)
  end

  def non_embedded_schema_fields(schema) do
    Enum.filter(schema.__schema__(:fields), fn field ->
      with {:embed, _} <- schema.__schema__(:type, field) do
        false
      else
        _ -> true
      end
    end)
  end
end
