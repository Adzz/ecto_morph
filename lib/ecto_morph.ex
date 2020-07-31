defmodule EctoMorph do
  @moduledoc """
  Utility functions for Ecto related stuff and things. Check out the functions docs to see what is
  available.
  """
  @typep ecto_struct :: Ecto.Schema.t()
  @typep schema_module :: atom()
  @typep okay_struct :: {:ok, ecto_struct}
  @typep error_changeset :: {:error, Ecto.Changeset.t()}

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
      ...> {:ok, test = %Test{}} = cast_to_struct(%{"pageviews" => "10"}, Test)
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
      ...> {:ok, test = %Test{}} = cast_to_struct(json, Test)
      ...> test.pageviews
      10
  """
  @spec cast_to_struct(map | ecto_struct, schema_module) :: okay_struct | error_changeset
  @spec cast_to_struct(map | ecto_struct, schema_module, list) :: okay_struct | error_changeset
  def cast_to_struct(data = %{__struct__: _}, schema) do
    Map.from_struct(data) |> cast_to_struct(schema)
  end

  def cast_to_struct(data, schema), do: generate_changeset(data, schema) |> into_struct()

  @doc """
  Takes some data and tries to convert it to a struct in the shape of the given schema. Casts values
  to the types defined by the schema dynamically using ecto changesets.

  Accepts a whitelist of fields that you allow updates / inserts on. This list of fields can define
  fields for inner schemas also like so:

  ```elixir
    EctoMorph.cast_to_struct(json, SchemaUnderTest, [
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
  def cast_to_struct(data = %{__struct__: _}, schema, fields) do
    Map.from_struct(data) |> cast_to_struct(schema, fields)
  end

  def cast_to_struct(data, schema, fields) do
    generate_changeset(data, schema, fields)
    |> into_struct
  end

  @doc """
  Attempts to update the given Ecto Schema struct with the given data by casting data and merging
  it into the struct. Uses `cast` and changesets to recursively update any nested relations also.

  Accepts a whitelist of fields for which updates can take place on. The whitelist can be arbitrarily
  nested, and Data may be a map, or another struct of any kind. See examples below.

  ### Examples

      iex> MyApp.Repo.get(Thing, 10) |> EctoMorph.update

  As with cast_to_struct, the data you are updating struct you are updating can be a
  """
  @spec update_struct(ecto_struct, map()) :: okay_struct | error_changeset
  @spec update_struct(ecto_struct, map(), list) :: okay_struct | error_changeset
  def update_struct(struct_to_update = %{__struct__: _}, data) do
    cast_to_struct(data, struct_to_update)
  end

  def update_struct(struct_to_update = %{__struct__: _}, data, field_whitelist) do
    cast_to_struct(data, struct_to_update, field_whitelist)
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
  @spec generate_changeset(map() | ecto_struct, schema_module | ecto_struct) :: Ecto.Changeset.t()
  def generate_changeset(data = %{__struct__: _}, schema) do
    generate_changeset(Map.from_struct(data), schema)
  end

  def generate_changeset(data, current = %{__struct__: schema}) do
    generate_changeset(
      data,
      current,
      schema_fields(schema) ++ schema_embeds(schema) ++ schema_associations(schema)
    )
  end

  def generate_changeset(data, schema), do: generate_changeset(data, struct(schema, %{}))

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
  @spec generate_changeset(map(), schema_module | ecto_struct, list) :: Ecto.Changeset.t()
  def generate_changeset(data = %{__struct__: _}, schema_or_existing_struct, fields) do
    generate_changeset(Map.from_struct(data), schema_or_existing_struct, fields)
  end

  def generate_changeset(data, current = %{__struct__: schema}, fields) do
    data = filter_not_loaded_relations(data)

    embedded_field_whitelist =
      Enum.filter(fields, fn
        {field, _} -> field in schema_embeds(schema)
        field -> field in schema_embeds(schema)
      end)

    assoc_field_whitelist =
      Enum.filter(fields, fn
        {field, _} -> field in schema_associations(schema)
        field -> field in schema_associations(schema)
      end)

    regular_field_whitelist =
      Enum.filter(fields, fn field -> field in schema_fields(schema) end)
      |> Enum.reject(fn field -> field in (assoc_field_whitelist ++ embedded_field_whitelist) end)

    # We only want to cast assocs / embeds if data contains fields that are embeds or assocs.
    # The data could very well have string keys though, but the result of schema_embeds and schema_associations
    # is a map of Atoms. We shouldn't use String.to_atom on data for obvious reasons, so let's go
    # the other way, and map schema_embeds to have string keys for the purpose of our check.
    allowed_changes =
      Enum.map(Map.keys(data), fn
        key when is_atom(key) -> Atom.to_string(key)
        key -> key
      end)

    making_embed_changes? =
      Enum.any?(allowed_changes, fn
        key ->
          key in Enum.map(embedded_field_whitelist, fn
            {field, _} -> Atom.to_string(field)
            field -> Atom.to_string(field)
          end)
      end)

    making_assoc_changes? =
      Enum.any?(allowed_changes, fn key ->
        key in Enum.map(assoc_field_whitelist, fn
          {field, _} -> Atom.to_string(field)
          field -> Atom.to_string(field)
        end)
      end)

    case {making_embed_changes?, making_assoc_changes?} do
      {false, false} ->
        cast(current, data, regular_field_whitelist)

      {false, true} ->
        cast(current, data, regular_field_whitelist)
        |> cast_assocs(assoc_field_whitelist)

      {true, false} ->
        cast(current, data, regular_field_whitelist)
        |> cast_embeds(embedded_field_whitelist)

      {true, true} ->
        cast(current, data, regular_field_whitelist)
        |> cast_assocs(assoc_field_whitelist)
        |> cast_embeds(embedded_field_whitelist)
    end
  end

  def generate_changeset(data, schema, fields) do
    generate_changeset(data, struct(schema, %{}), fields)
  end

  defp filter_not_loaded_relations(map = %{}) do
    Enum.filter(map, fn
      {_, %Ecto.Association.NotLoaded{}} -> false
      _ -> true
    end)
    |> Enum.into(%{})
  end

  @doc """
  Returns a map of all of the schema fields contained within data, optionally includes associations
  and embeds like so:

      iex> filter_by_schema_fields(%{id: 1}, MySchema, [:include_assocs])
      iex> filter_by_schema_fields(%{id: 2}, MySchema, [:include_embeds])
      iex> filter_by_schema_fields(%{id: 3}, MySchema, [include_assocs, :include_embeds])
  """
  @spec filter_by_schema_fields(map(), schema_module, list()) :: map()
  def filter_by_schema_fields(data, schema, options \\ []) do
    options_mapping = %{
      :include_assocs => schema_associations(schema),
      :include_embeds => schema_embeds(schema)
    }

    fields =
      Enum.reduce(options, schema_fields(schema), fn option, acc ->
        acc ++ Map.get(options_mapping, option, [])
      end)

    Map.take(data, fields)
  end

  @doc """
  Take a changeset and returns a struct if there are no errors on the changeset. Returns an error
  tuple with the invalid changeset otherwise.
  """
  @spec into_struct(Ecto.Changeset.t()) :: okay_struct | error_changeset
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
      :exclude_id => [:id]
    }

    fields_to_drop =
      Enum.reduce(options, [:__meta__], fn option, acc ->
        acc ++ Map.get(mapping, option, [])
      end)

    Map.from_struct(struct)
    |> Map.drop(fields_to_drop)
  end

  defmodule InvalidPathError do
    @moduledoc """
    validate_nested_changeset requires a path in which each location points to a nested changeset.
    If we are not given that, we raise an error.
    """
    defexception message:
                   "EctoMorph.validate_nested_changeset/3 requires that each field " <>
                     "in the path_to_nested_changeset points to a nested changeset."
  end

  defmodule InvalidValidationFunction do
    defexception message:
                   "Validation functions are expected to take a changeset and to return one"
  end

  @doc """
  Allows us to specify validations for nested changesets. Accepts a path to a nested changeset,
  and a validation function. The validation fun will be passed the changeset at the end of the
  path, and the result of the validation function will be merged back into the parent changeset.

  If a changeset is invalid, the parent will also be marked as valid?: false (as well as any
  changeset between the root changeset and the nested one), but the error messages will remain
  on the changeset they are relevant for. This is in line with how Ecto works elsewhere like
  in cast_embed etc. To get the nested error messages you can use `Ecto.Changeset.traverse_errors`

  This works with has_many relations by validating the list of changesets. If you are validating
  their nested relations, each changeset in the list must have the nested relation in their changes.

  ### Examples

  ```elixir
  EctoMorph.generate_changeset(%{nested: %{foo: 3}})
  |> EctoMorph.validate_nested_changeset([:nested], fn changeset ->
    Ecto.Changeset.validate_number(changeset, :foo, greater_than: 5)
  end)

  changeset = EctoMorph.generate_changeset(%{nested: %{double_nested: %{field: 6}}})
  EctoMorph.validate_nested_changeset(changeset, [:nested, :double_nested], &MySchema.validate/1)
  ```
  """
  def validate_nested_changeset(_, [], _) do
    raise InvalidPathError, "You must provide at least one field in the path"
  end

  def validate_nested_changeset(changeset, path_to_nested_changeset, validation_fun) do
    walk_the_path({[{nil, changeset}], path_to_nested_changeset}, validation_fun)
  end

  def walk_the_path({[{field, parent = %Ecto.Changeset{}}], []}, validation_fun) do
    with validated = %Ecto.Changeset{} <- validation_fun.(parent) do
      validated
    else
      _ -> raise InvalidValidationFunction
    end
  end

  def walk_the_path({[{field, child}, {_, parent = %Ecto.Changeset{}}], []}, validation_fun) do
    with validated = %Ecto.Changeset{} <- validation_fun.(child) do
      new_changes = %{parent.changes | field => validated}
      retreat(%{parent | changes: new_changes, valid?: validated.valid?}, [])
    else
      _ -> raise InvalidValidationFunction
    end
  end

  def walk_the_path({[{field, child} | rest = [{_, parent} | _]], []}, validation_fun) do
    with validated = %Ecto.Changeset{} <- validation_fun.(child) do
      new_changes = %{parent.changes | field => validated}
      retreat(%{parent | changes: new_changes, valid?: validated.valid?}, rest)
    else
      _ -> raise InvalidValidationFunction
    end
  end

  def walk_the_path({prev_changesets = [{_, parent} | _], [field | rest]}, validation_fun) do
    case Map.get(parent.changes, field) do
      nested_changeset = %Ecto.Changeset{} ->
        walk_the_path({[{field, nested_changeset} | prev_changesets], rest}, validation_fun)

      changesets = [%Ecto.Changeset{} | _] ->
        {valid?, changes} =
          Enum.reduce(changesets, {true, []}, fn nested_changeset, {valid, acc} ->
            result = walk_the_path({[{field, nested_changeset}], rest}, validation_fun)
            {valid && result.valid?, [result | acc]}
          end)

        new_changes = %{parent.changes | field => Enum.reverse(changes)}
        %{parent | changes: new_changes, valid?: valid?}

      _ ->
        raise InvalidPathError, """
        EctoMorph.validate_nested_changeset/3 requires that each field in the path_to_nested_changeset
        points to a nested changeset. It looks like :#{field} points to a change that isn't a nested
        changeset, or doesn't exist at all.
        """
    end
  end

  def retreat(changeset, []) do
    changeset
  end

  def retreat(changeset, [{field, _}, {_, parent = %Ecto.Changeset{}}]) do
    new_changes = %{parent.changes | field => changeset}
    %{parent | changes: new_changes, valid?: changeset.valid?}
  end

  def retreat(changeset, [{field, _} | rest = [{_, parent} | _]]) do
    new_changes = %{parent.changes | field => changeset}
    retreat(%{parent | changes: new_changes, valid?: changeset.valid?}, rest)
  end

  defp cast_embeds(changeset, relations) do
    Enum.reduce(relations, changeset, fn
      {relation, fields}, changeset ->
        Ecto.Changeset.cast_embed(changeset, relation,
          with: fn struct, changes ->
            generate_changeset(changes, struct, fields)
          end
        )

      relation, changeset ->
        Ecto.Changeset.cast_embed(changeset, relation,
          with: fn struct, changes -> generate_changeset(changes, struct) end
        )
    end)
  end

  defp cast_assocs(changeset, relations) do
    Enum.reduce(relations, changeset, fn
      {relation, fields}, changeset ->
        Ecto.Changeset.cast_assoc(changeset, relation,
          with: fn struct, changes ->
            generate_changeset(changes, struct, fields)
          end
        )

      relation, changeset ->
        Ecto.Changeset.cast_assoc(changeset, relation,
          with: fn struct, changes -> generate_changeset(changes, struct) end
        )
    end)
  end

  defp cast(current, data, fields) do
    Ecto.Changeset.cast(current, data, fields)
  end

  defp schema_embeds(schema) do
    schema.__schema__(:embeds)
  end

  defp schema_fields(schema) do
    schema.__schema__(:fields)
  end

  defp schema_associations(schema) do
    # __schema__(associations) will include through associations but through assocs cannot be
    # casted with cast_assoc, so we just filter them out here.
    schema.__schema__(:associations)
    |> Enum.filter(fn assoc ->
      # If the through assoc is not in the __changeset__ map, then it can go!
      Map.get(schema.__changeset__(), assoc, false)
    end)
  end
end
