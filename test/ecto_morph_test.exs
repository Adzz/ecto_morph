defmodule EctoMorphTest do
  use ExUnit.Case, async: false

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
      assert schema_under_test.custom_type == %A{a: "b", id: nil, number: 10}

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
               %SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %SteamedHams{
                 double_nested_schema: %DoubleNestedSchema{
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
               %SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %SteamedHams{
                 double_nested_schema: %DoubleNestedSchema{
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

  describe "cast_to_struct!/2" do
    test "Converts the decoded JSON into a struct of the provided schema, casting the values appropriately",
         %{json: json} do
      schema_under_test = %SchemaUnderTest{} = EctoMorph.cast_to_struct!(json, SchemaUnderTest)

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
      assert schema_under_test.custom_type == %A{a: "b", id: nil, number: 10}

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
      result = EctoMorph.cast_to_struct!(%SchemaUnderTest{integer: 1}, SchemaUnderTest)
      assert result.integer == 1

      result = EctoMorph.cast_to_struct!(%NonEctoStruct{integer: 1}, SchemaUnderTest)
      assert result.integer == 1
    end

    test "If the incoming changes are a struct, we filter out any unloaded changesets" do
      updated_struct =
        %TableBackedSchema{thing: "update"}
        |> EctoMorph.cast_to_struct!(TableBackedSchema)

      assert updated_struct.thing == "update"

      updated_struct =
        %TableBackedSchema{thing: "update"}
        |> EctoMorph.cast_to_struct!(TableBackedSchema, [:thing])

      assert updated_struct.thing == "update"

      updated_struct =
        %TableBackedSchema{thing: "update", has_one: %HasOne{hen_to_eat: 12}}
        |> EctoMorph.cast_to_struct!(TableBackedSchema, [:thing, has_one: [:hen_to_eat]])

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
      result = EctoMorph.cast_to_struct!(%{integer: 1}, struct_to_update)

      assert result.integer == 1
      assert result.binary == "yis"

      result = EctoMorph.cast_to_struct!(%{integer: 1}, struct_to_update)
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

      message =
        "could not perform create because changeset is invalid.\n\nErrors\n\n    %{\n      steamed_hams: [\n        %{pickles: [{\"is invalid\", [type: :integer, validation: :cast]}]}\n      ]\n    }\n\nApplied changes\n\n    %{\n      aurora_borealis: %{\n        actually_a_fire?: false,\n        location: \"Kitchen\",\n        probability: #Decimal<0.001>\n      },\n      steamed_hams: [%{meat_type: \"beef\", sauce_ratio: #Decimal<0.5>}]\n    }\n\nParams\n\n    %{\n      \"aurora_borealis\" => %{\n        \"actually_a_fire?\" => false,\n        \"location\" => \"Kitchen\",\n        \"probability\" => \"0.001\"\n      },\n      \"field_to_ignore\" => \"ensures we just ignore fields that are not part of the schema\",\n      \"steamed_hams\" => [\n        %{\"meat_type\" => \"beef\", \"pickles\" => false, \"sauce_ratio\" => \"0.5\"}\n      ]\n    }\n\nChangeset\n\n    #Ecto.Changeset<\n      action: :create,\n      changes: %{\n        aurora_borealis: #Ecto.Changeset<\n          action: :insert,\n          changes: %{\n            actually_a_fire?: false,\n            location: \"Kitchen\",\n            probability: #Decimal<0.001>\n          },\n          errors: [],\n          data: #AuroraBorealis<>,\n          valid?: true\n        >,\n        steamed_hams: [\n          #Ecto.Changeset<\n            action: :insert,\n            changes: %{meat_type: \"beef\", sauce_ratio: #Decimal<0.5>},\n            errors: [pickles: {\"is invalid\", [type: :integer, validation: :cast]}],\n            data: #SteamedHams<>,\n            valid?: false\n          >\n        ]\n      },\n      errors: [],\n      data: #SchemaUnderTest<>,\n      valid?: false\n    >\n"

      assert_raise(Ecto.InvalidChangesetError, message, fn ->
        EctoMorph.cast_to_struct!(json, SchemaUnderTest)
      end)
    end

    test "raises when a embeds_one embed is invalid" do
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

      message =
        "could not perform create because changeset is invalid.\n\nErrors\n\n    %{\n      aurora_borealis: %{\n        actually_a_fire?: [{\"is invalid\", [type: :boolean, validation: :cast]}]\n      }\n    }\n\nApplied changes\n\n    %{\n      aurora_borealis: %{location: \"Kitchen\", probability: #Decimal<0.001>},\n      steamed_hams: [%{meat_type: \"beef\", pickles: 2, sauce_ratio: #Decimal<0.5>}]\n    }\n\nParams\n\n    %{\n      \"aurora_borealis\" => %{\n        \"actually_a_fire?\" => \"YES\",\n        \"location\" => \"Kitchen\",\n        \"probability\" => \"0.001\"\n      },\n      \"field_to_ignore\" => \"ensures we just ignore fields that are not part of the schema\",\n      \"steamed_hams\" => [\n        %{\"meat_type\" => \"beef\", \"pickles\" => 2, \"sauce_ratio\" => \"0.5\"}\n      ]\n    }\n\nChangeset\n\n    #Ecto.Changeset<\n      action: :create,\n      changes: %{\n        aurora_borealis: #Ecto.Changeset<\n          action: :insert,\n          changes: %{location: \"Kitchen\", probability: #Decimal<0.001>},\n          errors: [\n            actually_a_fire?: {\"is invalid\", [type: :boolean, validation: :cast]}\n          ],\n          data: #AuroraBorealis<>,\n          valid?: false\n        >,\n        steamed_hams: [\n          #Ecto.Changeset<\n            action: :insert,\n            changes: %{meat_type: \"beef\", pickles: 2, sauce_ratio: #Decimal<0.5>},\n            errors: [],\n            data: #SteamedHams<>,\n            valid?: true\n          >\n        ]\n      },\n      errors: [],\n      data: #SchemaUnderTest<>,\n      valid?: false\n    >\n"

      assert_raise(Ecto.InvalidChangesetError, message, fn ->
        EctoMorph.cast_to_struct!(json, SchemaUnderTest)
      end)
    end

    test "Allows us to specify a subset of fields", %{json: json} do
      schema_under_test =
        %SchemaUnderTest{} =
        EctoMorph.cast_to_struct!(json, SchemaUnderTest, [
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
               %SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %SteamedHams{
                 double_nested_schema: %DoubleNestedSchema{
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

      schema_under_test =
        %SchemaUnderTest{} =
        EctoMorph.cast_to_struct!(
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
               %SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %SteamedHams{
                 double_nested_schema: %DoubleNestedSchema{
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
               %SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %SteamedHams{
                 double_nested_schema: %DoubleNestedSchema{
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
               %SteamedHams{
                 double_nested_schema: nil,
                 id: nil,
                 meat_type: nil,
                 pickles: 2,
                 sauce_ratio: nil
               },
               %SteamedHams{
                 double_nested_schema: %DoubleNestedSchema{
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
                   data: %SteamedHams{},
                   valid?: true
                 },
                 %Ecto.Changeset{
                   action: :insert,
                   changes: %{
                     double_nested_schema: %Ecto.Changeset{
                       action: :insert,
                       changes: %{value: "works!"},
                       errors: [],
                       data: %DoubleNestedSchema{},
                       valid?: true
                     },
                     pickles: 1
                   },
                   errors: [],
                   data: %SteamedHams{},
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
                   data: %SteamedHams{},
                   valid?: true
                 },
                 %Ecto.Changeset{
                   action: :insert,
                   changes: %{
                     double_nested_schema: %Ecto.Changeset{
                       action: :insert,
                       changes: %{value: "works!"},
                       errors: [],
                       data: %DoubleNestedSchema{},
                       valid?: true
                     },
                     pickles: 1
                   },
                   errors: [],
                   data: %SteamedHams{},
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
      {:ok, schema_under_test = %SchemaUnderTest{}} =
        json
        |> EctoMorph.generate_changeset(SchemaUnderTest)
        |> EctoMorph.into_struct()

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

  describe "into_struct!/2" do
    test "returns the result of Ecto.Changeset.apply_changes if passed a valid changeset", %{
      json: json
    } do
      schema_under_test =
        json
        |> EctoMorph.generate_changeset(SchemaUnderTest)
        |> EctoMorph.into_struct!()

      # {:ok, schema_under_test = %SchemaUnderTest{}} =
      #   EctoMorph.cast_to_struct(json, SchemaUnderTest)

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

    test "raises an error with an invalid changeset if passed an invalid changeset" do
      changeset =
        EctoMorph.generate_changeset(%{"date" => "last day of the month"}, SchemaUnderTest)

      error =
        "could not perform create because changeset is invalid.\n\nErrors\n\n    %{date: [{\"is invalid\", [type: :date, validation: :cast]}]}\n\nApplied changes\n\n    %{}\n\nParams\n\n    %{\"date\" => \"last day of the month\"}\n\nChangeset\n\n    #Ecto.Changeset<\n      action: :create,\n      changes: %{},\n      errors: [date: {\"is invalid\", [type: :date, validation: :cast]}],\n      data: #SchemaUnderTest<>,\n      valid?: false\n    >\n"

      assert_raise(Ecto.InvalidChangesetError, error, fn ->
        EctoMorph.into_struct!(changeset)
      end)
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
end
