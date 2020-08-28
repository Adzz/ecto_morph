defmodule EctoMorphTest do
  use ExUnit.Case

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

      embeds_many(:steamed_hams, SteamedHams, on_replace: :delete)
      embeds_one(:steamed_ham, SteamedHams)
      embeds_one(:aurora_borealis, AuroraBorealis)
      field(:custom_type, CustomType)
    end
  end

  defmodule NonEctoStruct do
    defstruct [:integer]
  end

  defmodule Through do
    use Ecto.Schema

    schema "through" do
      field(:rad_level, :integer)
    end
  end

  defmodule HasMany do
    use Ecto.Schema

    schema "newest_table" do
      field(:geese_to_feed, :integer)
      has_one(:through, Through)
      has_many(:steamed_hams, SteamedHams)
    end
  end

  defmodule HasOne do
    use Ecto.Schema

    schema "other_table" do
      field(:hen_to_eat, :integer)
      has_one(:steamed_ham, SteamedHams)
    end
  end

  defmodule TableBackedSchema do
    use Ecto.Schema

    schema "test_table" do
      field(:thing, :string)
      embeds_one(:aurora_borealis, AuroraBorealis)
      has_one(:has_one, HasOne)
      has_many(:has_many, HasMany)
      has_many(:throughs, through: [:has_many, :through])
    end
  end

  setup do
    %{
      json: %{
        "binary_id" => "this_is_a_binary_id",
        "integer" => "77",
        "float" => "1.7",
        "boolean" => false,
        "name" => "Super Nintendo Chalmers",
        "binary" => "It's a regional dialect",
        "array_of_ints" => ["1", "2", "3", "4"],
        "map" => %{"Seymour!" => "The house is on fire", "on_fire" => true},
        "map_of_integers" => %{"one" => "1", "two" => "2"},
        "percentage" => "2.5",
        "date" => "2018-05-05",
        "time" => "10:30:01.000001",
        "naive_datetime" => "2000-02-29T00:00:00",
        "naive_datetime_usec" => "2000-02-29T00:00:00",
        "utc_datetime" => "2019-04-08T14:31:14.366732Z",
        "utc_datetime_usec" => "2019-04-08T14:31:14.366732Z",
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => 2, "sauce_ratio" => "0.5"},
          %{
            "meat_type" => "chicken",
            "pickles" => 1,
            "sauce_ratio" => "0.7",
            "double_nested_schema" => %{"value" => "works!"}
          }
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        },
        "custom_type" => %{"a" => "b", "number" => 10},
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }
    }
  end

  describe "cast_to_struct/2" do
    test "Converts the decoded JSON into a struct of the provided schema, casting the values appropriately",
         %{json: json} do
      {:ok, schema_under_test = %SchemaUnderTest{}} =
        EctoMorph.cast_to_struct(json, SchemaUnderTest)

      assert schema_under_test.binary_id == "this_is_a_binary_id"
      assert schema_under_test.integer == 77
      assert schema_under_test.float == 1.7
      assert schema_under_test.boolean == false
      assert schema_under_test.name == "Super Nintendo Chalmers"
      assert schema_under_test.binary == "It's a regional dialect"
      assert schema_under_test.array_of_ints == [1, 2, 3, 4]
      assert schema_under_test.map == %{"on_fire" => true, "Seymour!" => "The house is on fire"}
      assert schema_under_test.map_of_integers == %{"one" => 1, "two" => 2}
      assert schema_under_test.percentage == Decimal.new("2.5")
      assert schema_under_test.date == ~D[2018-05-05]
      assert schema_under_test.time == ~T[10:30:01]
      assert schema_under_test.naive_datetime == ~N[2000-02-29 00:00:00]
      assert schema_under_test.naive_datetime_usec == ~N[2000-02-29 00:00:00.000000]
      assert schema_under_test.utc_datetime |> DateTime.to_string() == "2019-04-08 14:31:14Z"
      assert schema_under_test.custom_type == %EctoMorphTest.A{a: "b", id: nil, number: 10}

      assert schema_under_test.utc_datetime_usec |> DateTime.to_string() ==
               "2019-04-08 14:31:14.366732Z"

      assert schema_under_test.aurora_borealis == %AuroraBorealis{
               location: "Kitchen",
               probability: Decimal.new("0.001"),
               actually_a_fire?: false
             }

      assert schema_under_test.steamed_hams == [
               %SteamedHams{
                 meat_type: "beef",
                 pickles: 2,
                 sauce_ratio: Decimal.new("0.5"),
                 double_nested_schema: nil
               },
               %SteamedHams{
                 meat_type: "chicken",
                 pickles: 1,
                 sauce_ratio: Decimal.new("0.7"),
                 double_nested_schema: %DoubleNestedSchema{value: "works!"}
               }
             ]
    end

    test "Allows structs as the map of data, simply calling Map.from_struct on it first" do
      {:ok, result} = EctoMorph.cast_to_struct(%SchemaUnderTest{integer: 1}, SchemaUnderTest)
      assert result.integer == 1

      {:ok, result} = EctoMorph.cast_to_struct(%NonEctoStruct{integer: 1}, SchemaUnderTest)
      assert result.integer == 1
    end

    test "If the incoming changes are a struct, we filter out any unloaded changesets" do
      {:ok, updated_struct} =
        %TableBackedSchema{thing: "update"}
        |> EctoMorph.cast_to_struct(TableBackedSchema)

      assert updated_struct.thing == "update"

      {:ok, updated_struct} =
        %TableBackedSchema{thing: "update"}
        |> EctoMorph.cast_to_struct(TableBackedSchema, [:thing])

      assert updated_struct.thing == "update"

      {:ok, updated_struct} =
        %TableBackedSchema{thing: "update", has_one: %HasOne{hen_to_eat: 12}}
        |> EctoMorph.cast_to_struct(TableBackedSchema, [:thing, has_one: [:hen_to_eat]])

      assert updated_struct.thing == "update"

      changeset =
        %TableBackedSchema{thing: "update"}
        |> EctoMorph.generate_changeset(TableBackedSchema)

      assert changeset.changes.thing == "update"
      assert changeset.valid?

      changeset =
        %TableBackedSchema{thing: "update"}
        |> EctoMorph.generate_changeset(TableBackedSchema, [:thing])

      assert changeset.changes.thing == "update"
      assert changeset.valid?

      changeset =
        %TableBackedSchema{thing: "update", has_one: %HasOne{hen_to_eat: 12}}
        |> EctoMorph.generate_changeset(TableBackedSchema, [:thing, has_one: [:hen_to_eat]])

      assert changeset.changes.thing == "update"
      assert changeset.valid?
    end

    test "Allows schema to be a struct, simply updating it if so" do
      struct_to_update = %SchemaUnderTest{integer: 2, binary: "yis"}

      {:ok, result} = EctoMorph.cast_to_struct(%{integer: 1}, struct_to_update)

      assert result.integer == 1
      assert result.binary == "yis"

      {:ok, result} = EctoMorph.cast_to_struct(%{integer: 1}, struct_to_update)
      assert result.integer == 1
      assert result.binary == "yis"
    end

    test "returns an invalid changeset when an embeds_many embed is invalid" do
      json = %{
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => false, "sauce_ratio" => "0.5"}
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        },
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }

      {:error,
       %Ecto.Changeset{
         valid?: false,
         errors: [],
         data: %SchemaUnderTest{},
         changes: changes
       }} = EctoMorph.cast_to_struct(json, SchemaUnderTest)

      [steamed_ham] = changes.steamed_hams

      refute steamed_ham.valid?
      assert steamed_ham.errors == [pickles: {"is invalid", [type: :integer, validation: :cast]}]
      assert changes.aurora_borealis.valid?
    end

    test "returns an invalid changeset when a embeds_one embed is invalid" do
      json = %{
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => 2, "sauce_ratio" => "0.5"}
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => "YES"
        },
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }

      {:error,
       %Ecto.Changeset{
         valid?: false,
         errors: [],
         data: %SchemaUnderTest{},
         changes: changes
       }} = EctoMorph.cast_to_struct(json, SchemaUnderTest)

      refute changes.aurora_borealis.valid?

      assert changes.aurora_borealis.errors == [
               actually_a_fire?: {"is invalid", [type: :boolean, validation: :cast]}
             ]

      [steamed_ham] = changes.steamed_hams
      assert steamed_ham.valid?
    end

    test "Allows us to specify a subset of fields", %{json: json} do
      {:ok, schema_under_test = %SchemaUnderTest{}} =
        EctoMorph.cast_to_struct(json, SchemaUnderTest, [
          :boolean,
          :name,
          :binary,
          :array_of_ints,
          steamed_hams: [:pickles, double_nested_schema: [:value]]
        ])

      assert schema_under_test.boolean == false
      assert schema_under_test.name == "Super Nintendo Chalmers"
      assert schema_under_test.binary == "It's a regional dialect"
      assert schema_under_test.array_of_ints == [1, 2, 3, 4]

      assert schema_under_test.steamed_hams == [
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: %EctoMorphTest.DoubleNestedSchema{
                   id: nil,
                   value: "works!"
                 },
                 id: nil,
                 meat_type: nil,
                 pickles: 1,
                 sauce_ratio: nil
               }
             ]
    end

    test "Allows the schema to be a struct whereby that struct will be updated - whitelisting fields",
         %{
           json: json
         } do
      # TODO Check that the white listing can handle this case:
      # [steamed_hams: :pickles]

      {:ok, schema_under_test = %SchemaUnderTest{}} =
        EctoMorph.cast_to_struct(
          json,
          %SchemaUnderTest{binary: "test", name: "Super Nintendo Chalmers"},
          [
            :boolean,
            :binary,
            :array_of_ints,
            steamed_hams: [:pickles, double_nested_schema: [:value]]
          ]
        )

      assert schema_under_test.boolean == false
      assert schema_under_test.name == "Super Nintendo Chalmers"
      assert schema_under_test.binary == "It's a regional dialect"
      assert schema_under_test.array_of_ints == [1, 2, 3, 4]

      assert schema_under_test.steamed_hams == [
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: %EctoMorphTest.DoubleNestedSchema{
                   id: nil,
                   value: "works!"
                 },
                 id: nil,
                 meat_type: nil,
                 pickles: 1,
                 sauce_ratio: nil
               }
             ]
    end
  end

  describe "update_struct/2" do
    test "Converts the decoded JSON into a struct of the provided schema, casting the values appropriately",
         %{json: json} do
      {:ok, schema_under_test = %SchemaUnderTest{}} =
        EctoMorph.update_struct(%SchemaUnderTest{}, json)

      assert schema_under_test.binary_id == "this_is_a_binary_id"
      assert schema_under_test.integer == 77
      assert schema_under_test.float == 1.7
      assert schema_under_test.boolean == false
      assert schema_under_test.name == "Super Nintendo Chalmers"
      assert schema_under_test.binary == "It's a regional dialect"
      assert schema_under_test.array_of_ints == [1, 2, 3, 4]
      assert schema_under_test.map == %{"on_fire" => true, "Seymour!" => "The house is on fire"}
      assert schema_under_test.map_of_integers == %{"one" => 1, "two" => 2}
      assert schema_under_test.percentage == Decimal.new("2.5")
      assert schema_under_test.date == ~D[2018-05-05]
      assert schema_under_test.time == ~T[10:30:01]
      assert schema_under_test.naive_datetime == ~N[2000-02-29 00:00:00]
      assert schema_under_test.naive_datetime_usec == ~N[2000-02-29 00:00:00.000000]
      assert schema_under_test.utc_datetime |> DateTime.to_string() == "2019-04-08 14:31:14Z"

      assert schema_under_test.utc_datetime_usec |> DateTime.to_string() ==
               "2019-04-08 14:31:14.366732Z"

      assert schema_under_test.aurora_borealis == %AuroraBorealis{
               location: "Kitchen",
               probability: Decimal.new("0.001"),
               actually_a_fire?: false
             }

      assert schema_under_test.steamed_hams == [
               %SteamedHams{
                 meat_type: "beef",
                 pickles: 2,
                 sauce_ratio: Decimal.new("0.5"),
                 double_nested_schema: nil
               },
               %SteamedHams{
                 meat_type: "chicken",
                 pickles: 1,
                 sauce_ratio: Decimal.new("0.7"),
                 double_nested_schema: %DoubleNestedSchema{value: "works!"}
               }
             ]
    end

    test "Allows structs as the map of data, simply calling Map.from_struct on it first" do
      {:ok, result} = EctoMorph.update_struct(%SchemaUnderTest{}, %SchemaUnderTest{integer: 1})
      assert result.integer == 1

      {:ok, result} = EctoMorph.update_struct(%SchemaUnderTest{}, %NonEctoStruct{integer: 1})
      assert result.integer == 1
    end

    test "Allows schema to be a struct, simply updating it if so" do
      struct_to_update = %SchemaUnderTest{integer: 2, binary: "yis"}

      {:ok, result} = EctoMorph.update_struct(struct_to_update, %{integer: 1})

      assert result.integer == 1
      assert result.binary == "yis"

      {:ok, result} = EctoMorph.update_struct(struct_to_update, %{integer: 1})
      assert result.integer == 1
      assert result.binary == "yis"
    end

    test "returns an invalid changeset when an embeds_many embed is invalid" do
      json = %{
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => false, "sauce_ratio" => "0.5"}
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        },
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }

      {:error,
       %Ecto.Changeset{
         valid?: false,
         errors: [],
         data: %SchemaUnderTest{},
         changes: changes
       }} = EctoMorph.update_struct(%SchemaUnderTest{}, json)

      [steamed_ham] = changes.steamed_hams

      refute steamed_ham.valid?
      assert steamed_ham.errors == [pickles: {"is invalid", [type: :integer, validation: :cast]}]
      assert changes.aurora_borealis.valid?
    end

    test "returns an invalid changeset when a embeds_one embed is invalid" do
      json = %{
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => 2, "sauce_ratio" => "0.5"}
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => "YES"
        },
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }

      {:error,
       %Ecto.Changeset{
         valid?: false,
         errors: [],
         data: %SchemaUnderTest{},
         changes: changes
       }} = EctoMorph.update_struct(%SchemaUnderTest{}, json)

      refute changes.aurora_borealis.valid?

      assert changes.aurora_borealis.errors == [
               actually_a_fire?: {"is invalid", [type: :boolean, validation: :cast]}
             ]

      [steamed_ham] = changes.steamed_hams
      assert steamed_ham.valid?
    end

    test "Allows us to specify a subset of fields", %{json: json} do
      {:ok, schema_under_test = %SchemaUnderTest{}} =
        EctoMorph.update_struct(%SchemaUnderTest{}, json, [
          :boolean,
          :name,
          :binary,
          :array_of_ints,
          steamed_hams: [:pickles, double_nested_schema: [:value]]
        ])

      assert schema_under_test.boolean == false
      assert schema_under_test.name == "Super Nintendo Chalmers"
      assert schema_under_test.binary == "It's a regional dialect"
      assert schema_under_test.array_of_ints == [1, 2, 3, 4]

      assert schema_under_test.steamed_hams == [
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: %EctoMorphTest.DoubleNestedSchema{
                   id: nil,
                   value: "works!"
                 },
                 id: nil,
                 meat_type: nil,
                 pickles: 1,
                 sauce_ratio: nil
               }
             ]
    end

    test "Allows the schema to be a struct whereby that struct will be updated - whitelisting fields",
         %{
           json: json
         } do
      {:ok, schema_under_test = %SchemaUnderTest{}} =
        EctoMorph.update_struct(
          %SchemaUnderTest{binary: "test", name: "Super Nintendo Chalmers"},
          json,
          [
            :boolean,
            :binary,
            :array_of_ints,
            steamed_hams: [:pickles, double_nested_schema: [:value]]
          ]
        )

      assert schema_under_test.boolean == false
      assert schema_under_test.name == "Super Nintendo Chalmers"
      assert schema_under_test.binary == "It's a regional dialect"
      assert schema_under_test.array_of_ints == [1, 2, 3, 4]

      assert schema_under_test.steamed_hams == [
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %EctoMorphTest.SteamedHams{
                 double_nested_schema: %EctoMorphTest.DoubleNestedSchema{
                   id: nil,
                   value: "works!"
                 },
                 id: nil,
                 meat_type: nil,
                 pickles: 1,
                 sauce_ratio: nil
               }
             ]
    end
  end

  describe "generate_changeset/2" do
    test "returns a valid changeset when it should", %{json: json} do
      %Ecto.Changeset{
        valid?: true,
        errors: [],
        data: %SchemaUnderTest{},
        changes: changes
      } = EctoMorph.generate_changeset(json, SchemaUnderTest)

      [steamed_ham_one, steamed_ham_two] = changes.steamed_hams

      assert steamed_ham_one.valid?
      assert steamed_ham_two.valid?
      assert changes.aurora_borealis.valid?
    end

    test "handles through relations by filtering them" do
      json = %{
        "has_one" => %{"hen_to_eat" => 10},
        # The through change will be filtered out, as it should because we are missing
        # ids from the tables in between.
        "has_many" => [%{"geese_to_feed" => 4, "through" => %{"rad_level" => 3}}]
      }

      changeset = EctoMorph.generate_changeset(json, TableBackedSchema)
      assert changeset.valid?
    end

    test "returns invalid changeset when the parent is invalid" do
      json = %{
        "date" => "last day of the month",
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => 2, "sauce_ratio" => "0.5"},
          %{"meat_type" => "chicken", "pickles" => 1, "sauce_ratio" => "0.7"}
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        },
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }

      %Ecto.Changeset{
        valid?: false,
        errors: errors,
        data: %SchemaUnderTest{},
        changes: changes
      } = EctoMorph.generate_changeset(json, SchemaUnderTest)

      assert errors == [date: {"is invalid", [type: :date, validation: :cast]}]

      [steamed_ham_one, steamed_ham_two] = changes.steamed_hams

      assert steamed_ham_one.valid?
      assert steamed_ham_two.valid?
      assert changes.aurora_borealis.valid?
    end

    test "returns an invalid changeset when one of the embeds is invalid" do
      json = %{
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => false, "sauce_ratio" => "0.5"}
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        },
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }

      %Ecto.Changeset{
        valid?: false,
        errors: [],
        data: %SchemaUnderTest{},
        changes: changes
      } = EctoMorph.generate_changeset(json, SchemaUnderTest)

      [steamed_ham] = changes.steamed_hams

      refute steamed_ham.valid?
      assert steamed_ham.errors == [pickles: {"is invalid", [type: :integer, validation: :cast]}]
      assert changes.aurora_borealis.valid?
    end

    test "Successfully creates a changeset for assocs" do
      json = %{
        "thing" => "lively",
        "has_one" => %{"hen_to_eat" => 0},
        "has_many" => [%{"geese_to_feed" => 10}],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        }
      }

      assert %Ecto.Changeset{
               valid?: true,
               errors: [],
               data: %TableBackedSchema{},
               changes: %{
                 thing: "lively",
                 has_one: associated_changeset,
                 has_many: [many_changeset],
                 aurora_borealis: aurora_borealis
               }
             } = EctoMorph.generate_changeset(json, %TableBackedSchema{})

      assert %Ecto.Changeset{
               valid?: true,
               errors: [],
               data: %HasOne{}
             } = associated_changeset

      assert %Ecto.Changeset{
               valid?: true,
               errors: [],
               data: %HasMany{}
             } = many_changeset

      assert %Ecto.Changeset{
               valid?: true,
               errors: [],
               data: %AuroraBorealis{}
             } = aurora_borealis

      assert associated_changeset.changes == %{hen_to_eat: 0}
      assert many_changeset.changes == %{geese_to_feed: 10}

      assert aurora_borealis.changes == %{
               actually_a_fire?: false,
               location: "Kitchen",
               probability: Decimal.new("0.001")
             }
    end

    test "creates changesets for both embeds and assocs" do
    end

    test "Accepts a struct as the first argument" do
      changeset = EctoMorph.generate_changeset(%NonEctoStruct{integer: 1}, SchemaUnderTest)
      assert changeset.valid?
      assert changeset.changes == %{integer: 1}
      assert changeset.errors == []
    end

    test "Accepts a struct as the schema" do
      changeset = EctoMorph.generate_changeset(%NonEctoStruct{integer: 1}, %SchemaUnderTest{})
      assert changeset.valid?
      assert changeset.changes == %{integer: 1}
      assert changeset.errors == []
    end

    test "Allows us to specify a subset of fields - nested relations", %{json: json} do
      changeset =
        %Ecto.Changeset{} =
        EctoMorph.generate_changeset(json, SchemaUnderTest, [
          :boolean,
          :name,
          :binary,
          :array_of_ints,
          steamed_hams: [:pickles, double_nested_schema: [:value]]
        ])

      assert changeset.valid? == true

      assert %{
               array_of_ints: [1, 2, 3, 4],
               binary: "It's a regional dialect",
               boolean: false,
               name: "Super Nintendo Chalmers",
               steamed_hams: [
                 %Ecto.Changeset{
                   action: :insert,
                   changes: %{pickles: 2},
                   errors: [],
                   data: %EctoMorphTest.SteamedHams{},
                   valid?: true
                 },
                 %Ecto.Changeset{
                   action: :insert,
                   changes: %{
                     double_nested_schema: %Ecto.Changeset{
                       action: :insert,
                       changes: %{value: "works!"},
                       errors: [],
                       data: %EctoMorphTest.DoubleNestedSchema{},
                       valid?: true
                     },
                     pickles: 1
                   },
                   errors: [],
                   data: %EctoMorphTest.SteamedHams{},
                   valid?: true
                 }
               ]
             } = changeset.changes
    end

    test "Allows us to specify a subset of fields - nested relations with schema as a struct", %{
      json: json
    } do
      changeset =
        %Ecto.Changeset{} =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{}, [
          :boolean,
          :name,
          :binary,
          :array_of_ints,
          steamed_hams: [:pickles, double_nested_schema: [:value]]
        ])

      assert changeset.valid? == true

      assert %{
               array_of_ints: [1, 2, 3, 4],
               binary: "It's a regional dialect",
               boolean: false,
               name: "Super Nintendo Chalmers",
               steamed_hams: [
                 %Ecto.Changeset{
                   action: :insert,
                   changes: %{pickles: 2},
                   errors: [],
                   data: %EctoMorphTest.SteamedHams{},
                   valid?: true
                 },
                 %Ecto.Changeset{
                   action: :insert,
                   changes: %{
                     double_nested_schema: %Ecto.Changeset{
                       action: :insert,
                       changes: %{value: "works!"},
                       errors: [],
                       data: %EctoMorphTest.DoubleNestedSchema{},
                       valid?: true
                     },
                     pickles: 1
                   },
                   errors: [],
                   data: %EctoMorphTest.SteamedHams{},
                   valid?: true
                 }
               ]
             } = changeset.changes
    end
  end

  describe "into_struct/2" do
    test "returns the result of Ecto.Changeset.apply_changes if passed a valid changeset", %{
      json: json
    } do
      json
      |> EctoMorph.generate_changeset(SchemaUnderTest)
      |> EctoMorph.into_struct()

      {:ok, schema_under_test = %SchemaUnderTest{}} =
        EctoMorph.cast_to_struct(json, SchemaUnderTest)

      assert schema_under_test.binary_id == "this_is_a_binary_id"
      assert schema_under_test.integer == 77
      assert schema_under_test.float == 1.7
      assert schema_under_test.boolean == false
      assert schema_under_test.name == "Super Nintendo Chalmers"
      assert schema_under_test.binary == "It's a regional dialect"
      assert schema_under_test.array_of_ints == [1, 2, 3, 4]
      assert schema_under_test.map == %{"on_fire" => true, "Seymour!" => "The house is on fire"}
      assert schema_under_test.map_of_integers == %{"one" => 1, "two" => 2}
      assert schema_under_test.percentage == Decimal.new("2.5")
      assert schema_under_test.date == ~D[2018-05-05]
      assert schema_under_test.time == ~T[10:30:01]
      assert schema_under_test.naive_datetime == ~N[2000-02-29 00:00:00]
      assert schema_under_test.naive_datetime_usec == ~N[2000-02-29 00:00:00.000000]
      assert schema_under_test.utc_datetime |> DateTime.to_string() == "2019-04-08 14:31:14Z"

      assert schema_under_test.utc_datetime_usec |> DateTime.to_string() ==
               "2019-04-08 14:31:14.366732Z"

      assert schema_under_test.aurora_borealis == %AuroraBorealis{
               location: "Kitchen",
               probability: Decimal.new("0.001"),
               actually_a_fire?: false
             }

      assert schema_under_test.steamed_hams == [
               %SteamedHams{
                 meat_type: "beef",
                 pickles: 2,
                 sauce_ratio: Decimal.new("0.5"),
                 double_nested_schema: nil
               },
               %SteamedHams{
                 meat_type: "chicken",
                 pickles: 1,
                 sauce_ratio: Decimal.new("0.7"),
                 double_nested_schema: %DoubleNestedSchema{value: "works!"}
               }
             ]
    end

    test "returns an error with an invalid changeset if passed an invalid changeset" do
      {:error, changeset} =
        %{"date" => "last day of the month"}
        |> EctoMorph.generate_changeset(SchemaUnderTest)
        |> EctoMorph.into_struct()

      assert changeset.errors == [date: {"is invalid", [type: :date, validation: :cast]}]
      refute changeset.valid?
    end
  end

  describe "map_from_struct/2" do
    test "creates a map from the struct, dropping the meta key" do
      assert EctoMorph.map_from_struct(%SteamedHams{}) == %{
               id: nil,
               meat_type: nil,
               pickles: nil,
               sauce_ratio: nil,
               double_nested_schema: nil
             }
    end

    test "drops the timestamps if the option is given" do
      assert EctoMorph.map_from_struct(%SchemaWithTimestamps{}, [:exclude_timestamps]) == %{
               foo: nil,
               id: nil
             }
    end

    test "drops the id if the option is provided" do
      assert EctoMorph.map_from_struct(%SchemaWithTimestamps{}, [:exclude_id]) == %{
               foo: nil,
               inserted_at: nil,
               updated_at: nil
             }
    end

    test "drops both if they are given" do
      assert EctoMorph.map_from_struct(%SchemaWithTimestamps{}, [:exclude_id, :exclude_timestamps]) ==
               %{
                 foo: nil
               }
    end

    test "an option that doesn't exist" do
      assert EctoMorph.map_from_struct(%SchemaWithTimestamps{}, [:banana, :exclude_timestamps]) ==
               %{
                 foo: nil,
                 id: nil
               }
    end
  end

  describe "filter_by_schema_fields/2" do
    test "returns all the fields in data that are schema fields" do
      data = %{not_in_the_schema: "1", location: 1, probability: 1, actually_a_fire: 1}

      assert EctoMorph.filter_by_schema_fields(data, AuroraBorealis) == %{
               location: 1,
               probability: 1
             }
    end

    test "includes assocs" do
      data = %{
        not_in_the_schema: "1",
        has_one: %{hen_to_eat: 1}
      }

      assert EctoMorph.filter_by_schema_fields(data, TableBackedSchema, [:include_assocs]) == %{
               has_one: %{hen_to_eat: 1}
             }
    end

    test "includes embeds" do
      data = %{
        not_in_the_schema: "1",
        aurora_borealis: %{location: 1}
      }

      assert EctoMorph.filter_by_schema_fields(data, TableBackedSchema, [:include_embeds]) == %{
               aurora_borealis: %{location: 1}
             }
    end

    test "includes embeds and assocs" do
      data = %{
        not_in_the_schema: "1",
        has_one: %{hen_to_eat: 1},
        aurora_borealis: %{location: 1}
      }

      assert EctoMorph.filter_by_schema_fields(data, TableBackedSchema, [
               :include_assocs,
               :include_embeds
             ]) == %{aurora_borealis: %{location: 1}, has_one: %{hen_to_eat: 1}}
    end
  end

  describe "Specifying validation funs" do
    test "Has one, 1 level nested", %{json: json} do
      # PASS
      result =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:aurora_borealis], fn changeset ->
          changeset
          |> Ecto.Changeset.validate_number(:probability, less_than: 5)
        end)

      assert result.valid? == true
      assert result.changes.aurora_borealis.errors == []

      # FAIL
      result =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:aurora_borealis], fn changeset ->
          changeset
          |> Ecto.Changeset.validate_number(:probability, greater_than: 5)
        end)

      assert result.valid? == false

      assert result.changes.aurora_borealis.errors == [
               {:probability,
                {"must be greater than %{number}",
                 [validation: :number, kind: :greater_than, number: 5]}}
             ]
    end

    test "has one that has one - multi nested schemas" do
      # PASS validation
      result =
        %{has_one: %{steamed_ham: %{double_nested_schema: %{value: "This is a string"}}}}
        |> EctoMorph.generate_changeset(TableBackedSchema)
        |> EctoMorph.validate_nested_changeset(
          [:has_one, :steamed_ham, :double_nested_schema],
          & &1
        )

      assert result.valid?

      # FAIL validation
      result =
        %{steamed_ham: %{double_nested_schema: %{value: "This is a string"}}}
        |> EctoMorph.generate_changeset(SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:steamed_ham, :double_nested_schema], fn ch ->
          Ecto.Changeset.validate_length(ch, :value, min: 50)
        end)

      assert result.valid? == false

      assert result.changes.steamed_ham.changes.double_nested_schema.errors == [
               {:value,
                {"should be at least %{count} character(s)",
                 [count: 50, validation: :length, kind: :min, type: :string]}}
             ]
    end

    test "Has many - all of them get validated.", %{json: json} do
      # Pass validation
      result =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:steamed_hams], fn changeset ->
          changeset
          |> Ecto.Changeset.validate_number(:pickles, less_than: 5)
        end)

      assert result.valid? == true
      assert Enum.map(result.changes.steamed_hams, & &1.errors) == [[], []]

      # Fail validation
      result =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:steamed_hams], fn changeset ->
          changeset
          |> Ecto.Changeset.validate_number(:pickles, greater_than: 55)
        end)

      assert result.valid? == false

      [first, second] = result.changes.steamed_hams
      assert first.valid? == false
      assert second.valid? == false

      assert first.errors == [
               {:pickles,
                {"must be greater than %{number}",
                 [validation: :number, kind: :greater_than, number: 55]}}
             ]

      assert second.errors == [
               {:pickles,
                {"must be greater than %{number}",
                 [validation: :number, kind: :greater_than, number: 55]}}
             ]
    end

    test "has_many that has_one " do
      json = %{
        steamed_hams: [
          %{double_nested_schema: %{value: "Hi"}},
          %{double_nested_schema: %{value: "Hi there"}},
          %{double_nested_schema: %{value: "Passing validation is easy"}}
        ]
      }

      result =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:steamed_hams, :double_nested_schema], fn ch ->
          Ecto.Changeset.validate_length(ch, :value, min: 15)
        end)

      assert result.valid? == false
      [first, second, third] = result.changes.steamed_hams

      assert first.changes.double_nested_schema.errors == [
               {:value,
                {"should be at least %{count} character(s)",
                 [count: 15, validation: :length, kind: :min, type: :string]}}
             ]

      assert second.changes.double_nested_schema.errors == [
               {:value,
                {"should be at least %{count} character(s)",
                 [count: 15, validation: :length, kind: :min, type: :string]}}
             ]

      assert third.changes.double_nested_schema.errors == []
    end

    test "has_many that has_many - all of them get validated, throughs are ignored" do
      json = %{
        "throughs" => %{"rad_level" => 16},
        "has_many" => [
          %{"steamed_hams" => [%{"pickles" => 1}, %{"pickles" => 2}]},
          %{"steamed_hams" => [%{"pickles" => 1}]},
          %{"steamed_hams" => [%{"pickles" => 4}, %{"pickles" => 5}]}
        ]
      }

      result =
        EctoMorph.generate_changeset(json, TableBackedSchema)
        |> EctoMorph.validate_nested_changeset([:has_many, :steamed_hams], fn changeset ->
          changeset
          |> Ecto.Changeset.validate_number(:pickles, greater_than: 3)
        end)

      [first, second, third] = result.changes.has_many

      [ham_1, ham_2] = first.changes.steamed_hams
      [ham_3] = second.changes.steamed_hams
      [ham_4, ham_5] = third.changes.steamed_hams

      assert ham_1.valid? == false

      assert ham_1.errors == [
               {:pickles,
                {"must be greater than %{number}",
                 [validation: :number, kind: :greater_than, number: 3]}}
             ]

      assert ham_2.valid? == false

      assert ham_2.errors == [
               {:pickles,
                {"must be greater than %{number}",
                 [validation: :number, kind: :greater_than, number: 3]}}
             ]

      assert ham_3.valid? == false

      assert ham_3.errors == [
               {:pickles,
                {"must be greater than %{number}",
                 [validation: :number, kind: :greater_than, number: 3]}}
             ]

      assert ham_4.valid?
      assert ham_4.errors == []
      assert ham_5.valid?
      assert ham_5.errors == []
    end

    test "when it's invalid" do
      json = %{"aurora_borealis" => %{"probability" => "0.001"}}

      ch =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:aurora_borealis], fn changeset ->
          changeset
          |> Ecto.Changeset.validate_number(:probability, greater_than: 5)
        end)

      refute ch.valid?

      assert ch.changes.aurora_borealis.errors == [
               {:probability,
                {"must be greater than %{number}",
                 [validation: :number, kind: :greater_than, number: 5]}}
             ]
    end

    test "When the path doesn't point to a changeset we raise an IncorrectPath error", %{
      json: json
    } do
      ch = EctoMorph.generate_changeset(json, SchemaUnderTest)

      error_message =
        "EctoMorph.validate_nested_changeset/3 requires that each field in the path_to_nested_changeset\npoints to a nested changeset. It looks like :not_a_field points to a change that isn't a nested\nchangeset, or doesn't exist at all.\n"

      assert_raise(EctoMorph.InvalidPathError, error_message, fn ->
        EctoMorph.validate_nested_changeset(ch, [:not_a_field], & &1)
      end)

      error_message =
        "EctoMorph.validate_nested_changeset/3 requires that each field in the path_to_nested_changeset\npoints to a nested changeset. It looks like :integer points to a change that isn't a nested\nchangeset, or doesn't exist at all.\n"

      assert_raise(EctoMorph.InvalidPathError, error_message, fn ->
        EctoMorph.validate_nested_changeset(ch, [:integer], & &1)
      end)

      assert_raise(EctoMorph.InvalidPathError, error_message, fn ->
        EctoMorph.validate_nested_changeset(ch, [:aurora_borealis, :integer], & &1)
      end)
    end

    test "empty path", %{json: json} do
      ch = EctoMorph.generate_changeset(json, SchemaUnderTest)
      error_message = "You must provide at least one field in the path"

      assert_raise(EctoMorph.InvalidPathError, error_message, fn ->
        EctoMorph.validate_nested_changeset(ch, [], & &1)
      end)
    end

    test "invalid validation function", %{json: json} do
      ch = EctoMorph.generate_changeset(json, SchemaUnderTest)
      error_message = "Validation functions are expected to take a changeset and to return one"

      assert_raise(EctoMorph.InvalidValidationFunction, error_message, fn ->
        EctoMorph.validate_nested_changeset(ch, [:aurora_borealis], fn _ -> :hi end)
      end)
    end

    test "Pointing to an empty list is allowed - we want to be able to delete relations" do
      json = %{"steamed_hams" => []}

      existing = %SchemaUnderTest{
        id: "1",
        steamed_hams: [
          %SteamedHams{id: "1", pickles: 10},
          %SteamedHams{id: "2", pickles: 12}
        ]
      }

      # Pass validation
      result =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:steamed_hams], fn changeset ->
          changeset
          |> Ecto.Changeset.validate_number(:pickles, less_than: 5)
        end)

      # There are not changes (as by default a SchemaUnderTest has no SteamedHams)
      assert result.valid? == true
      assert result.changes == %{}

      # Fail validation
      result =
        EctoMorph.generate_changeset(json, existing)
        |> EctoMorph.validate_nested_changeset([:steamed_hams], fn changeset ->
          changeset
          # Becuase on_replace is set to delete the changeset is always valid.
          |> Ecto.Changeset.validate_number(:pickles, greater_than: 55)
        end)

      assert result.valid? == true

      [first, second] = result.changes.steamed_hams
      # Becuase on_replace is set to delete the changeset is always valid.
      assert first.valid? == true
      assert second.valid? == true
      assert first.errors == []
      assert first.action == :replace
      assert second.action == :replace
    end

    test "has_one that has_one no changes to validate" do
      # PASS validation
      result =
        %{has_one: %{steamed_ham: %{double_nested_schema: %{value: "This is a string"}}}}
        |> EctoMorph.generate_changeset(TableBackedSchema)
        |> EctoMorph.validate_nested_changeset(
          [:has_one, :steamed_ham, :double_nested_schema],
          & &1
        )

      assert result.valid?

      # FAIL validation
      result =
        %{steamed_ham: %{double_nested_schema: %{}}}
        |> EctoMorph.generate_changeset(SchemaUnderTest)
        |> EctoMorph.validate_nested_changeset([:steamed_ham, :double_nested_schema], fn ch ->
          Ecto.Changeset.validate_length(ch, :value, min: 50)
        end)

      assert result.valid? == true
      assert result.changes.steamed_ham.changes.double_nested_schema.errors == []
      assert result.changes.steamed_ham.changes.double_nested_schema.changes == %{}
    end
  end
end
