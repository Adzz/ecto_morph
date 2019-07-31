defmodule EctoMorph do
  @moduledoc """
  Utility functions for Ecto related stuff and things. Check out the functions docs to see what is
  available.
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

  Here we take care of casting the values in the json to the type that the given schema defines, as
  well as turning the string keys into (existing) atoms. (We know they will be existing atoms
  because they will exist in the schema definitions.)

  We filter out any keys that are not defined in the schema, and if the first argument is a struct,
  we call Map.from_struct/1 on it first. This can be useful for converting data between structs.

  Check out the tests for more full examples.

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
  @spec to_struct(map_with_string_keys | ecto_struct, ecto_schema_module) ::
          {:ok, ecto_struct} | {:error, Ecto.Changeset.t()}
  @spec to_struct(map_with_string_keys | ecto_struct, ecto_schema_module, list) ::
          {:ok, ecto_struct} | {:error, Ecto.Changeset.t()}
  def to_struct(data = %{__struct__: _}, schema), do: Map.from_struct(data) |> to_struct(schema)
  def to_struct(data, schema), do: generate_changeset(data, schema) |> into_struct()

  @doc """
  Takes some data and tries to convert it to a struct in the shape of the given schema. Casts values
  to the types defined by the schema dynamically using ecto changesets.

  Accepts a whitelist of fields that you allow updates / inserts on. This list of fields can define
  fields for inner schemas also like so:

  ```elixir
    EctoMorph.to_struct(json, SchemaUnderTest, [
      :boolean,
      :name,
      :binary,
      :array_of_ints,
      steamed_hams: [:pickles, double_nested_schema: [:value]]
    ])
  ```

  We filter out any keys that are not defined in the schema, and if the first argument is a struct,
  we call Map.from_struct/1 on it first. This can be useful for converting data between structs.
  """
  def to_struct(data = %{__struct__: _}, schema, fields) do
    Map.from_struct(data) |> to_struct(schema, fields)
  end

  def to_struct(data, schema, fields) do
    generate_changeset(data, schema, fields)
    |> into_struct
  end

  @doc """
  Casts the given data into a changeset according to the types defined by the given `schema`. It
  ignores any fields in `data` that are not defined in the schema, and recursively casts any embedded
  fields to a changeset also. Accepts a different struct as the first argument, calling Map.to_struct
  on it first. Also allows the schema to be an existing struct, in which case it will infer the schema
  from the struct, and effectively update that struct with the changes supplied in data.

  ### Examples

  ```elixir
      ...> data = %{
      ...>  "integer" => "77",
      ...>  "steamed_hams" => [%{
      ...>    "pickles" => 1,
      ...>    "sauce_ratio" => "0.7",
      ...>    "double_nested_schema" => %{"value" => "works!"}
      ...>  }],
      ...> }
      ...> EctoMorph.generate_changeset(data, %SchemaUnderTest{integer: 2})
      ...>
  ```
  """
  @spec generate_changeset(map() | ecto_struct, ecto_schema_module | ecto_struct) ::
          Ecto.Changeset.t()
  def generate_changeset(data = %{__struct__: _}, schema) do
    generate_changeset(Map.from_struct(data), schema)
  end

  def generate_changeset(data, current = %{__struct__: schema}) do
    with [] <- embedded_schema_fields(schema) do
      current
      |> Ecto.Changeset.cast(data, schema.__schema__(:fields))
    else
      embedded_fields ->
        current
        |> Ecto.Changeset.cast(data, non_embedded_schema_fields(schema))
        |> cast_all_the_embeds(embedded_fields)
    end
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

  @doc """
  Takes in a map of data and creates a changeset out of it by casting the data recursively, according
  to the whitelist of fields in fields. The map of data may be a struct, and the fields whitelist
  can whitelist fields of nested relations by providing a list for them as well.

  ### Examples

  If we provide a whitelist of fields, we will be passed a changeset for the changes on those fields
  only:
  ```elixir
      ...> data = %{
      ...>  "integer" => "77",
      ...>  "steamed_hams" => [%{
      ...>    "pickles" => 1,
      ...>    "sauce_ratio" => "0.7",
      ...>    "double_nested_schema" => %{"value" => "works!"}
      ...>  }],
      ...> }
      ...> EctoMorph.generate_changeset(data, SchemaUnderTest, [:integer])
      ...>
  ```

  We can also define whitelists for any arbitrarily deep relation like so:
  ```elixir
      ...> data = %{
      ...>  "integer" => "77",
      ...>  "steamed_hams" => [%{
      ...>    "pickles" => 1,
      ...>    "sauce_ratio" => "0.7",
      ...>    "double_nested_schema" => %{"value" => "works!"}
      ...>  }],
      ...> }
      ...> EctoMorph.generate_changeset(data, SchemaUnderTest, [
      ...>   :integer,
      ...>   steamed_hams: [:pickles, double_nested_schema: [:value]]
      ...> ])
  ```
  """
  @spec generate_changeset(map() | ecto_struct, ecto_schema_module | ecto_struct, list) ::
          Ecto.Changeset.t()
  def generate_changeset(data = %{__struct__: _}, schema_or_existing_struct, fields) do
    generate_changeset(Map.from_struct(data), schema_or_existing_struct, fields)
  end

  def generate_changeset(data, schema_or_existing_struct, fields) do
    with [] <- embedded_allowed_fields(fields) do
      schema_or_existing_struct
      |> struct!(%{})
      |> Ecto.Changeset.cast(data, fields)
    else
      embedded_fields ->
        schema_or_existing_struct
        |> struct!(%{})
        |> Ecto.Changeset.cast(data, non_embedded_allowed_fields(fields))
        |> cast_embeded_fields(embedded_fields)
    end
  end

  @doc "Returns a map of all of the schema fields contained within data"
  @spec filter_by_schema_fields(map(), ecto_schema_module) :: map()
  def filter_by_schema_fields(data, schema) do
    Map.take(data, schema.__schema__(:fields))
  end

  @doc """
  Take a changeset and returns a struct if there are no errors on the changeset. Returns an error
  tuple with the invalid changeset otherwise.
  """
  @spec into_struct(Ecto.Changeset.t()) :: {:ok, ecto_struct} | {:error, Ecto.Changeset.t()}
  def into_struct(changeset = %{valid?: true}), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
  def into_struct(changeset), do: {:error, changeset}

  @doc """
  Creates a map out of the Ecto struct, removing the internal ecto fields. Optionally you can remove
  the inserted_at and updated_at timestamp fields also by passing in :exclude_timestamps as an option

  ### Examples

      iex> map_from_struct(%Test{}, [:exclude_timestamps])
      %Test{foo: "bar", id: 10}

      iex> map_from_struct(%Test{})
      %Test{foo: "bar", updated_at: ~N[2000-01-01 23:00:07], inserted_at: ~N[2000-01-01 23:00:07], id: 10}

      iex> map_from_struct(%Test{}, [:exclude_timestamps, :exclude_id])
      %Test{foo: "bar"}
  """
  @spec map_from_struct(ecto_struct) :: map()
  @spec map_from_struct(ecto_struct, list()) :: map()
  def map_from_struct(struct, options \\ []) do
    mapping = %{
      :exclude_timestamps => [:inserted_at, :updated_at],
      :exclude_id => [:id],
      nil => []
    }

    fields_to_drop =
      Enum.reduce(options, [:__meta__], fn option, acc ->
        acc ++ Map.get(mapping, option, nil)
      end)

    Map.from_struct(struct)
    |> Map.drop(fields_to_drop)
  end

  defp cast_embeded_fields(changeset, embedded_fields) do
    Enum.reduce(embedded_fields, changeset, fn {embedded_field, fields}, changeset ->
      Ecto.Changeset.cast_embed(changeset, embedded_field,
        with: fn struct, changes ->
          generate_changeset(changes, struct.__struct__, fields)
        end
      )
    end)
  end

  defp cast_all_the_embeds(changeset, embedded_fields) do
    Enum.reduce(embedded_fields, changeset, fn embedded_field, changeset ->
      Ecto.Changeset.cast_embed(changeset, embedded_field,
        with: fn struct, changes -> generate_changeset(changes, struct.__struct__) end
      )
    end)
  end

  defp non_embedded_allowed_fields(fields) do
    fields
    |> Enum.filter(fn
      {_embedded_field_name, _field} -> false
      field when is_atom(field) -> true
    end)
  end

  defp embedded_allowed_fields(fields) do
    fields
    |> Enum.filter(fn
      {_embedded_field_name, _field} -> true
      field when is_atom(field) -> false
    end)
  end

  defp embedded_schema_fields(schema) do
    Enum.filter(schema.__schema__(:fields), fn field ->
      with {:embed, _} <- schema.__schema__(:type, field) do
        true
      else
        _ -> false
      end
    end)
  end

  defp non_embedded_schema_fields(schema) do
    Enum.filter(schema.__schema__(:fields), fn field ->
      with {:embed, _} <- schema.__schema__(:type, field) do
        false
      else
        _ -> true
      end
    end)
  end
end
