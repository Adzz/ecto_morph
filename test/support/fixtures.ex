defmodule A do
  use Ecto.Schema

  embedded_schema do
    field(:a, :string)
    field(:number, :integer)
  end

  def changeset(changes) do
    EctoMorph.generate_changeset(changes, __MODULE__)
    |> Ecto.Changeset.validate_number(:number, greater_than: 5)
    |> EctoMorph.into_struct()
    |> case do
      {:ok, struct} -> {:ok, struct}
      # this ensures these errors appear as errors on the parent...
      # Add to the medium Article about this. Or make a part two and also include the API
      # in ecto morph to specify the validation function.
      {:error, changeset} -> {:error, changeset.errors}
    end
  end
end

defmodule B do
  use Ecto.Schema

  embedded_schema do
    field(:a, :string)
    field(:name, :string)
  end
end

defmodule CustomType do
  use Ecto.Type
  def type, do: :map

  def cast(thing = %{"a" => "b"}) do
    A.changeset(thing)
  end

  def cast(thing = %{a: "b"}) do
    EctoMorph.cast_to_struct(thing, A)
  end

  def cast(thing = %{"a" => "a"}) do
    EctoMorph.cast_to_struct(thing, B)
  end

  def cast(thing = %{a: "a"}) do
    EctoMorph.cast_to_struct(thing, B)
  end

  def dump(_), do: raise("This will never be called")
  def load(_), do: raise("This will never be called")
end

defmodule SchemaWithTimestamps do
  use Ecto.Schema

  embedded_schema do
    field(:foo, :string)
    field(:updated_at, :naive_datetime_usec)
    field(:inserted_at, :naive_datetime_usec)
  end
end

defmodule DoubleNestedSchema do
  use Ecto.Schema

  embedded_schema do
    field(:value, :string)
  end
end

defmodule SteamedHams do
  use Ecto.Schema

  embedded_schema do
    field(:meat_type, :string)
    field(:pickles, :integer)
    field(:sauce_ratio, :decimal)
    field(:has_many_id, :string)
    field(:has_one_id, :string)
    embeds_one(:double_nested_schema, DoubleNestedSchema)
  end
end

defmodule AuroraBorealis do
  use Ecto.Schema

  embedded_schema do
    field(:location, :string)
    field(:probability, :decimal)
    field(:actually_a_fire?, :boolean)
  end
end

defmodule NonEctoStruct do
  defstruct [:integer]
end

defmodule Through do
  use Ecto.Schema

  schema "through" do
    field(:rad_level, :integer)
    field(:has_many_id, :string)
  end
end

defmodule HasMany do
  use Ecto.Schema

  schema "newest_table" do
    field(:geese_to_feed, :integer)
    field(:table_backed_schema_id, :string)
    field(:schema_under_test_id, :string)
    field(:overlap_and_some_id, :string)
    field(:nested_has_many_id, :string)
    has_one(:through, Through)
    has_many(:steamed_hams, SteamedHams)
  end
end

defmodule NestedHasMany do
  use Ecto.Schema

  schema "nested_has_many" do
    field(:table_backed_schema_id, :string)
    field(:schema_under_test_id, :string)

    has_one(:has_many, HasMany)
  end
end

defmodule HasOne do
  use Ecto.Schema

  schema "other_table" do
    field(:hen_to_eat, :integer)
    field(:table_backed_schema_id, :string)
    has_one(:steamed_ham, SteamedHams)
  end
end

defmodule TableBackedSchema do
  use Ecto.Schema

  schema "test_table" do
    field(:thing, :string)
    field(:test, :string, virtual: true)
    embeds_one(:aurora_borealis, AuroraBorealis)
    has_one(:has_one, HasOne)
    has_many(:has_many, HasMany)
    has_many(:throughs, through: [:has_many, :through])
  end
end

defmodule SchemaUnderTest do
  use Ecto.Schema

  embedded_schema do
    field(:binary_id, :binary_id)
    field(:integer, :integer)
    field(:float, :float)
    field(:boolean, :boolean)
    field(:name, :string, default: "Seymour!")
    field(:binary, :binary)
    field(:array_of_ints, {:array, :integer})
    field(:map, :map)
    field(:map_of_integers, {:map, :integer})
    field(:percentage, :decimal)
    field(:date, :date)
    field(:time, :time)
    field(:naive_datetime, :naive_datetime)
    field(:naive_datetime_usec, :naive_datetime_usec)
    field(:utc_datetime, :utc_datetime)
    field(:utc_datetime_usec, :utc_datetime_usec)
    has_many(:has_many, HasMany)
    has_many(:throughs, through: [:has_many, :through])
    embeds_many(:steamed_hams, SteamedHams, on_replace: :delete)
    embeds_one(:steamed_ham, SteamedHams)
    embeds_one(:aurora_borealis, AuroraBorealis)
    field(:custom_type, CustomType)
  end
end

defmodule OverlapAndSome do
  use Ecto.Schema

  embedded_schema do
    field(:ignored, :string)
    field(:filltered, :string)
    field(:binary_id, :binary_id)
    field(:integer, :integer)
    field(:float, :float)
    field(:boolean, :boolean)
    field(:name, :string, default: "Seymour!")
    field(:binary, :binary)
    field(:array_of_ints, {:array, :integer})
    field(:map, :map)
    field(:map_of_integers, {:map, :integer})
    field(:percentage, :decimal)
    field(:date, :date)
    field(:time, :time)
    field(:naive_datetime, :naive_datetime)
    field(:naive_datetime_usec, :naive_datetime_usec)
    field(:utc_datetime, :utc_datetime)
    field(:utc_datetime_usec, :utc_datetime_usec)
    has_many(:has_many, HasMany)
    has_many(:throughs, through: [:has_many, :through])

    embeds_many(:steamed_hams, SteamedHams, on_replace: :delete)
    embeds_one(:steamed_ham, SteamedHams)
    embeds_one(:aurora_borealis, AuroraBorealis)
  end
end

defmodule NonEctoOverlapAndSome do
  defstruct [
    :ignored,
    :filltered,
    :binary_id,
    :integer,
    :float,
    :boolean,
    :name,
    :binary,
    :array_of_ints,
    :map,
    :map_of_integers,
    :percentage,
    :date,
    :time,
    :naive_datetime,
    :naive_datetime_usec,
    :utc_datetime,
    :utc_datetime_usec,
    :has_many,
    :throughs,
    :steamed_hams,
    :steamed_ham,
    :aurora_borealis
  ]
end
