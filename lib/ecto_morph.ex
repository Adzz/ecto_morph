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

  @spec cast_to_struct!(map | ecto_struct, schema_module) :: okay_struct | error_changeset
  @spec cast_to_struct!(map | ecto_struct, schema_module, list) :: okay_struct | error_changeset

  @doc """
  Same as `cast_to_struct/2`, but raises if the data fails casting.
  """
  def cast_to_struct!(data = %{__struct__: _}, schema) do
    Map.from_struct(data) |> cast_to_struct!(schema)
  end

  def cast_to_struct!(data, schema), do: generate_changeset(data, schema) |> into_struct!()

  @doc """
  Same as `cast_to_struct/3`, but raises if the data fails casting.
  """
  def cast_to_struct!(data = %{__struct__: _}, schema, fields) do
    Map.from_struct(data) |> cast_to_struct!(schema, fields)
  end

  def cast_to_struct!(data, schema, fields) do
    generate_changeset(data, schema, fields)
    |> into_struct!
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
  Returns a map of all of the schema fields contained within data. This is not recursive so look
  at deep_filter_by_schema_fields if you want a recursive version.

  ### Options

    * filter_not_loaded - This will nillify any Ecto.Association.NotLoaded structs in the map,
                          setting the value to be nil for any non loaded association.

      iex> data = %{id: 1, other: %Ecto.Association.NotLoaded{}}
      ...> filter_by_schema_fields(data, MySchema, filter_not_loaded: true)
      %{id: 1, other: nil}

      iex> data = %{id: 1, other: %AnotherOne{}}
      ...> filter_by_schema_fields(data, MySchema)
      %{id: 1, other: %AnotherOne{}}
  """
  @spec filter_by_schema_fields(map(), schema_module, list()) :: map()
  def filter_by_schema_fields(data, schema, opts \\ []) do
    filter? = Keyword.get(opts, :filter_not_loaded, false)

    Map.take(data, all_schema_fields(schema))
    |> Enum.into(%{}, fn
      {key, %Ecto.Association.NotLoaded{} = v} -> if filter?, do: {key, nil}, else: {key, v}
      {key, nil} -> {key, nil}
      {key, value} -> {key, value}
    end)
  end

  @doc """
  Deep filters the data to only include those fields that appear in the given schema and in any of
  the given schema's relations.

  If the schema `has_one(:foo, Foo)` and data has `:foo` as an key, then the value under `:foo`
  in data will be filtered by the fields in Foo. This will happen for all casts, embeds, and virtual
  fields. There is no way to determine via reflection which schema a through relation points to,
  so by default they are filtered by their own schema if they are a map.

  This is useful for converting a struct into a map, eliminating internal Ecto fields in the
  process.

  ### Options

  When filtering you can optionally choose to nillify Ecto.Association.NotLoaded structs. By
  default they are passed through as is, but you can nillify them like this:

  `deep_filter_by_schema_fields(data, MySchema, filter_not_loaded: true)`

  ### Examples

      iex> deep_filter_by_schema_fields(%{a: "c", ignored: true, stuff: "nope"}, A)
      %{a: "c"}

      iex> data = %{relation: %Ecto.Association.NotLoaded{}}
      ...> deep_filter_by_schema_fields(data, A, filter_not_loaded: true)
      %{relation: nil}
  """
  def deep_filter_by_schema_fields(data, schema, opts \\ []) when is_map(data) do
    filter_not_loaded = Keyword.get(opts, :filter_not_loaded, false)

    # This does not include through assocs. With them, we would not be able to figure out the schema
    # they are on... meaning we won't know the fields to filter by so we just return it as is.
    # If the through assoc points to a struct we filter it by itself to turn it to a map.
    relations = schema_associations(schema) ++ schema_embeds(schema)

    Map.take(data, all_schema_fields(schema))
    |> Enum.into(%{}, fn
      {key, %Ecto.Association.NotLoaded{} = value} ->
        if filter_not_loaded do
          {key, nil}
        else
          {key, value}
        end

      {key, nil} ->
        {key, nil}

      {key, value} ->
        # If it is a through relation I don't think we have a way to introspect what schema it
        # belongs to. Which means we may just have to pass it as is... Which means we don't filter
        # the fields of the through relation.
        if key in relations do
          {_, %{related: relation_schema}} = Map.fetch!(schema.__changeset__(), key)

          if is_list(value) do
            # Has / embeds many
            {key, Enum.map(value, &deep_filter_by_schema_fields(&1, relation_schema))}
          else
            {key, deep_filter_by_schema_fields(value, relation_schema)}
          end
        else
          # Do we handle non ecto structs as the data being filtered...
          if key in throughs(schema) do
            case value do
              # This essentially tries to work for through relations if it's a struct by
              # getting the struct schema out of the struct.
              %{__struct__: relation_schema} = value ->
                {key, deep_filter_by_schema_fields(value, relation_schema)}

              value when is_list(value) ->
                {key, Enum.map(value, &deep_filter_by_schema_fields(&1, schema))}

              value ->
                {key, value}
            end
          else
            {key, value}
          end
        end
    end)
  end

  @doc """
  Take a changeset and returns a struct if there are no errors on the changeset. Returns an error
  tuple with the invalid changeset otherwise.
  """
  @spec into_struct(Ecto.Changeset.t()) :: okay_struct | error_changeset
  def into_struct(changeset = %{valid?: true}), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
  def into_struct(changeset), do: {:error, changeset}

  @doc """
  Essentially a wrapper around Ecto.Changeset.apply_action! where the action is create.
  It will create a struct out of a valid changeset and raise in the case of an invalid one.
  """
  @spec into_struct!(Ecto.Changeset.t()) :: struct() | no_return
  def into_struct!(changeset) do
    Ecto.Changeset.apply_action!(changeset, :create)
  end

  @doc """
  Creates a map out of the Ecto struct, removing the internal ecto fields. Optionally you can remove
  the inserted_at and updated_at timestamp fields also by passing in :exclude_timestamps as an option

  This function is not deep. Prefer `deep_filter_by_schema_fields` or `filter_by_schema_fields`

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

  If you provide a path to changeset that does not exist in changes....

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
  # Now the natural question is can we extend this to allow the Repo.preload syntax ? I.e. a tree?
  # [:this, plus: :this, and: [:also, these: :too]] ? I think the zipper Idea helps that along a lot.

  # so let's extract the traversal. And let's have it be a keyword lens maybe. The simplest way
  # is to expand the lens and traverse it then. But after extracting the traversal.
  def validate_nested_changeset(_, [], _) do
    raise InvalidPathError, "You must provide at least one field in the path"
  end

  def validate_nested_changeset(changeset, path, validation) do
    fun = fn
      {_, ch} ->
        ch

      parent ->
        with validated = %Ecto.Changeset{} <- validation.(parent) do
          validated
        else
          _ -> raise InvalidValidationFunction
        end
    end

    map(changeset, path, fun)
  end

  # Runs the given fun for the nested changeset at the end of the given path, and merges the result
  # back into parent. If the nested changeset is a *_many relation, each of the provided relations
  # will be passed to the fun.

  # This can be seen as a useful lower level function to enable a bunch of other functions. It
  # essentially abstracts the traversal which has the following rules:

  #   1. Pointing to something that isn't a changeset raises an InvalidPathError.
  #     (this ensures we are working on changesets.)
  #   2. Each *_many relation gets visited.
  #   3. All changes are merged back into the parent changeset.
  defp map(changeset, [], _), do: changeset

  defp map(changeset, path_to_nested_changeset, map_fun) do
    walk_the_path({[{nil, changeset}], path_to_nested_changeset}, map_fun)
  end

  defp walk_the_path({[{_, parent = %Ecto.Changeset{}}], []}, map_fun) do
    map_fun.(parent)
  end

  defp walk_the_path({[{field, child}, {_, parent = %Ecto.Changeset{}}], []}, map_fun) do
    validated = map_fun.(child)
    new_changes = %{parent.changes | field => validated}
    # If the parent is invalid then it needs to stay that way even if the child is valid.
    # So we want to make the parent invalid if the child was invalid, but otherwise let
    # it be whatever the parent already was.
    retreat(%{parent | changes: new_changes, valid?: parent.valid? && validated.valid?}, [])
  end

  defp walk_the_path({[{field, child} | rest = [{_, parent} | _]], []}, map_fun) do
    validated = map_fun.(child)
    new_changes = %{parent.changes | field => validated}
    valid? = parent.valid? && validated.valid?
    retreat(%{parent | changes: new_changes, valid?: valid?}, rest)
  end

  defp walk_the_path({prev_changesets = [{_, parent} | _], [field | rest]}, map_fun) do
    schema = parent.data.__struct__

    if not (field in (schema_fields(schema) ++
                        schema_embeds(schema) ++ schema_associations(schema))) do
      raise InvalidPathError,
            "Each field in the path_to_nested_changeset should point to a nested changeset. It looks " <>
              "like :#{field} is not a field on #{schema}.\n\nNB: You cannot validate through " <>
              "relations."
    end

    if map_size(parent.changes) == 0 do
      parent
    else
      case Map.get(parent.changes, field) do
        nested_changeset = %Ecto.Changeset{} ->
          walk_the_path({[{field, nested_changeset} | prev_changesets], rest}, map_fun)

        changesets = [%Ecto.Changeset{} | _] ->
          {valid?, changes} =
            Enum.reduce(changesets, {parent.valid?, []}, fn nested_changeset, {valid, acc} ->
              result = walk_the_path({[{field, nested_changeset}], rest}, map_fun)
              {valid && result.valid?, [result | acc]}
            end)

          new_changes = %{parent.changes | field => Enum.reverse(changes)}
          %{parent | changes: new_changes, valid?: valid?}

        # If the changes aren't in the changeset, then there is nothing to validate, we can't
        # validate something that isn't there, and it may be legit to have a changeset validation
        # run always, but sometimes that change isn't in it. Think of a partial update.
        # The tradeoff is that it's now a bit easier to pass in an incorrect path and not realize
        # But... there should be tests for that anyway.

        # However that makes it impossible to validate_required because we need to know more info
        # basically all options SUCK, this is a hacky solution for now, prevents us from making
        # map public...

        # The real problem here is that we are traversing a thing, and if the path we are traversing
        # ends I need to know. But really what I need to be given in that case could vary
        # depending on our use case......
        nil ->
          map_fun.({field, parent})

        [] ->
          # I suppose really [] is only allowed for cardinality :many.... but whatever.
          map_fun.({field, parent})

        _ ->
          raise InvalidPathError,
                "Each field in the path_to_nested_changeset should point to a nested changeset." <>
                  " It looks like :#{field} points to a change that isn't a nested changeset."
      end
    end
  end

  defp retreat(changeset, []), do: changeset

  defp retreat(changeset, [{field, _}, {_, parent = %Ecto.Changeset{}}]) do
    new_changes = %{parent.changes | field => changeset}
    valid? = changeset.valid? && parent.valid?
    %{parent | changes: new_changes, valid?: valid?}
  end

  defp retreat(changeset, [{field, _} | rest = [{_, parent} | _]]) do
    new_changes = %{parent.changes | field => changeset}
    valid? = changeset.valid? && parent.valid?
    retreat(%{parent | changes: new_changes, valid?: valid?}, rest)
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

  @doc """
  Validates whether a changeset has a the given fields. You can pass in relations and they will
  be required, and you can pass in nested keys which will also be validated.

  For the relations, this follows the semantics of Ecto.Changeset.validate_required and will check
  changes for a non null relation, then check data. If either are non null the validation will
  pass allowing the possibility for partial updates.

  ### Examples

    EctoMorph.generate_changeset(%{my: :data, relation: %{}}, MyModule)
    |> EctoMorph.validate_required([:relation])

    EctoMorph.generate_changeset(%{my: :data, relation: %{nested_thing: %{}}}, MyModule)
    |> EctoMorph.validate_required([relation: :nested_thing])

    data = %{my: :data, relation: %{nested_thing: %{thing: 1}}}
    EctoMorph.validate_required(data, [relation: [nested_thing: :thing]])
  """
  def validate_required(changeset, path) do
    schema = changeset.data.__struct__
    relations = schema_embeds(schema) ++ schema_associations(schema)

    # We choose to expand the keyword like lens to make the implementation simpler. Otherwise
    # the traverse gets very error prone and tricky. But it's not a simple KeywordLens.expand
    # because we end up with a flat list of tuples, each with the path to the fields to be
    # validated on the left, and fields that are required on the right. If the left list
    # is empty it means the fields are on the top level.
    expand_path(path)
    |> Enum.reduce(changeset, fn
      {[], fields}, change ->
        {relation_fields, normal_fields} =
          Enum.split_with(fields, fn field -> field in relations end)

        Ecto.Changeset.validate_required(change, normal_fields)
        |> validate_required_relations(relation_fields)

      {path_to_nested, fields}, change ->
        map(change, path_to_nested, fn
          # This case we know the change does not have the field we are trying to ensure
          # exists in the changes (or data ?)
          # We need to also know which field we are trying to get. This is basically trash
          # as it means we cant make map public because it has a very weird API...
          {field, ch} ->
            errors = [{field, {"can't be blank", [validation: :required]}} | ch.errors]
            %{ch | errors: errors, valid?: false}

          ch ->
            {relation_fields, normal_fields} =
              Enum.split_with(fields, fn field -> field in relations end)

            Ecto.Changeset.validate_required(ch, normal_fields)
            |> validate_required_relations(relation_fields)
        end)
    end)
  end

  # This function turns [nested: [:thing, another: [:thing, :third]]] into
  # [{[:nested], [:thing]}, {[:nested, :another], [:thing, :third]}]

  @doc false
  # This function is public to test, but should be considered private to library users.
  def expand_path(fields), do: expand_path(fields, {[], []})

  @doc false
  # This function is public to test, but should be considered private to library users.
  def expand_path([], {_parent, acc}), do: Enum.reverse(acc)

  # We should only get here from reducing.
  def expand_path({field, nested}, {parent, acc}) when is_atom(nested) do
    [{Enum.reverse([field | parent]), [nested]} | acc]
  end

  def expand_path({field, nested}, {parent, acc}) when is_list(nested) do
    new_parent = [field | parent]

    case split_fields(nested) do
      [top_level, nested_fields] ->
        start = {new_parent, [{Enum.reverse(new_parent), top_level} | acc]}

        {_, result} =
          Enum.reduce(nested_fields, start, fn f, {parent, acc} ->
            {parent, expand_path(f, {parent, acc})}
          end)

        Enum.reverse(result)

      [[x | _] = top_level_fields] when is_atom(x) ->
        [{Enum.reverse(new_parent), top_level_fields} | acc]

      [[{_, _} | _] = nested_fields] ->
        {_, result} =
          Enum.reduce(nested_fields, {new_parent, acc}, fn f, {parent, acc} ->
            {parent, expand_path(f, {parent, acc})}
          end)

        Enum.reverse(result)
    end
  end

  def expand_path([{field, nested} | rest], {parent, acc}) when is_atom(nested) do
    new_parent = [field | parent]
    expand_path(rest, {new_parent, [{Enum.reverse(new_parent), [nested]} | acc]})
  end

  def expand_path([{field, nested} | rest], {parent, acc}) when is_list(nested) do
    new_parent = [field | parent]

    case split_fields(nested) do
      [top_level, nested_fields] ->
        start = {new_parent, [{Enum.reverse(new_parent), top_level} | acc]}

        new_acc =
          Enum.reduce(nested_fields, start, fn f, {parent, acc} ->
            {parent, expand_path(f, {parent, acc})}
          end)

        expand_path(rest, new_acc)

      [[x | _] = top_level_fields] when is_atom(x) ->
        expand_path(rest, {new_parent, [{Enum.reverse(new_parent), top_level_fields} | acc]})

      [[{_, _} | _] = nested_fields] ->
        {_, new_acc} =
          Enum.reduce(nested_fields, {new_parent, acc}, fn f, {parent, acc} ->
            {parent, expand_path(f, {parent, acc})}
          end)

        expand_path(rest, {parent, new_acc})
    end
  end

  def expand_path(fields, {[], []}) when is_list(fields) do
    case split_fields(fields) do
      [top_level, nested_fields] ->
        {_, result} =
          Enum.reduce(nested_fields, {[], [{[], top_level}]}, fn f, {parent, acc} ->
            # Each item in here needs to know the parent. getting it from the prev
            # doesn't work because the next iteration overwrites it..... so we need to
            # keep that state.....
            {parent, expand_path(f, {parent, acc})}
          end)

        Enum.reverse(result)

      [[x | _] = top_level_fields] when is_atom(x) ->
        [{[], top_level_fields}]
    end
  end

  def split_fields(fields) do
    # This is probably better as split_with. Refactor when we have more better tests.
    Enum.chunk_by(fields, fn
      {_, _} -> true
      _ -> false
    end)
  end

  defp validate_required_relations(changeset, relations) do
    Enum.reduce(relations, changeset, fn r, acc -> validate_required_relation(acc, r) end)
  end

  defp validate_required_relation(
         %Ecto.Changeset{changes: changes, data: data} = changeset,
         relation_field
       ) do
    schema = data.__struct__
    # Once you start in data you continue down the path in data
    # But up till then you always check changes first.
    with {_, relation} <- Map.get(schema.__changeset__(), relation_field, :not_found) do
      relation_in_changes = Map.get(changes, relation_field)
      relation_in_data = Map.fetch!(data, relation_field)
      relation_not_in_changes? = empty_relation?(relation, relation_in_changes)
      relation_not_in_data? = empty_relation?(relation, relation_in_data)

      if relation_not_in_changes? do
        if relation_not_in_data? do
          errors = [
            {relation_field, {"can't be blank", [validation: :required]}} | changeset.errors
          ]

          %{changeset | errors: errors, valid?: false}
        else
          changeset
        end
      else
        changeset
      end
    else
      :not_found ->
        raise InvalidPathError,
              "The path pointed to a field that is not on the schema" <>
                " please ensure the path is correct."
    end
  end

  # Checks if the container can be considered empty. Copied and slightly modified from
  # Ecto.Changeset.Relation
  defp empty_relation?(%{cardinality: _}, %Ecto.Association.NotLoaded{}), do: true
  defp empty_relation?(%{cardinality: _}, nil), do: true
  defp empty_relation?(%{cardinality: :many}, []), do: true
  defp empty_relation?(%{cardinality: :many}, changes), do: filter_empty(changes) == []
  defp empty_relation?(%{}, _), do: false

  defp filter_empty(changes) do
    Enum.filter(changes, fn
      %Ecto.Changeset{action: action} when action in [:replace, :delete] -> false
      _ -> true
    end)
  end

  defp cast(current, data, fields) do
    Ecto.Changeset.cast(current, data, fields)
  end

  # Map.keys(schema.__changeset__()) will include virtual fields and assocs and embeds BUT will
  # not include through associations. It's a bit weird, but if you want everything you have to mix
  # and match a bit...
  defp all_schema_fields(schema) do
    # If you do this: Map.keys(struct(schema)) -- [:__meta__, :__struct__]
    # it would work but might cause issues if new private keys are added.
    (Map.keys(schema.__changeset__()) ++ schema.__schema__(:associations)) |> Enum.uniq()
  end

  defp schema_embeds(schema) do
    schema.__schema__(:embeds)
  end

  defp schema_fields(schema) do
    schema.__schema__(:fields)
  end

  defp throughs(schema) do
    # __schema__(associations) will include through associations but through assocs aren't
    # in __changeset__
    schema.__schema__(:associations)
    |> Enum.reject(fn assoc ->
      # If the through assoc is not in the __changeset__ map, then it can go!
      Map.get(schema.__changeset__(), assoc, false)
    end)
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
