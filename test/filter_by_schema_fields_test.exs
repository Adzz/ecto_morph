defmodule FilterBySchemaFieldsTest do
  use ExUnit.Case, async: false

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

      assert EctoMorph.filter_by_schema_fields(data, TableBackedSchema) == %{
               has_one: %{hen_to_eat: 1}
             }
    end

    test "includes embeds" do
      data = %{
        not_in_the_schema: "1",
        aurora_borealis: %{location: 1}
      }

      assert EctoMorph.filter_by_schema_fields(data, TableBackedSchema) == %{
               aurora_borealis: %{location: 1}
             }
    end

    test "filters assocs" do
      data = %{
        not_in_the_schema: "1",
        has_one: %{hen_to_eat: 1},
        aurora_borealis: %{location: 1}
      }

      assert EctoMorph.filter_by_schema_fields(data, TableBackedSchema, filter_assocs: true) ==
               %{}
    end

    test "struct as data - filter assocs" do
      data = %OverlapAndSome{
        binary_id: 1,
        ignored: "not a fields",
        filltered: "this is filtered",
        has_many: nil,
        steamed_hams: [
          %SteamedHams{
            meat_type: "beef",
            pickles: 2,
            sauce_ratio: Decimal.new("0.5"),
            double_nested_schema: %{value: "works!"}
          }
        ]
      }

      result = EctoMorph.filter_by_schema_fields(data, SchemaUnderTest, filter_assocs: true)

      assert result == %{
               array_of_ints: nil,
               binary: nil,
               binary_id: 1,
               boolean: nil,
               date: nil,
               float: nil,
               id: nil,
               integer: nil,
               map: nil,
               map_of_integers: nil,
               naive_datetime: nil,
               naive_datetime_usec: nil,
               name: "Seymour!",
               percentage: nil,
               time: nil,
               utc_datetime: nil,
               utc_datetime_usec: nil
             }
    end

    test "struct as data" do
      data = %OverlapAndSome{
        binary_id: 1,
        ignored: "not a fields",
        filltered: "this is filtered",
        has_many: nil,
        steamed_hams: [
          %SteamedHams{
            meat_type: "beef",
            pickles: 2,
            sauce_ratio: Decimal.new("0.5"),
            double_nested_schema: %{value: "works!"}
          }
        ]
      }

      result = EctoMorph.filter_by_schema_fields(data, SchemaUnderTest, filter_not_loaded: true)

      assert result == %{
               array_of_ints: nil,
               aurora_borealis: nil,
               binary: nil,
               binary_id: 1,
               boolean: nil,
               date: nil,
               float: nil,
               has_many: nil,
               id: nil,
               integer: nil,
               map: nil,
               map_of_integers: nil,
               naive_datetime: nil,
               naive_datetime_usec: nil,
               name: "Seymour!",
               percentage: nil,
               steamed_ham: nil,
               steamed_hams: [
                 %SteamedHams{
                   double_nested_schema: %{value: "works!"},
                   id: nil,
                   meat_type: "beef",
                   pickles: 2,
                   sauce_ratio: Decimal.new("0.5")
                 }
               ],
               throughs: nil,
               time: nil,
               utc_datetime: nil,
               utc_datetime_usec: nil
             }
    end

    test "Non ecto struct" do
      data = %NonEctoStruct{integer: 1}
      result = EctoMorph.deep_filter_by_schema_fields(data, SchemaUnderTest)
      assert result == %{integer: 1}

      data = %NonEctoOverlapAndSome{
        binary_id: 1,
        ignored: "not a fields",
        filltered: "this is filtered",
        has_many: nil,
        throughs: %HasMany{steamed_hams: nil, through: %Through{}},
        steamed_hams: [
          %SteamedHams{
            meat_type: "beef",
            pickles: 2,
            sauce_ratio: Decimal.new("0.5"),
            double_nested_schema: %{value: "works!"}
          }
        ]
      }

      result = EctoMorph.filter_by_schema_fields(data, SchemaUnderTest)

      assert result == %{
               array_of_ints: nil,
               aurora_borealis: nil,
               binary: nil,
               binary_id: 1,
               boolean: nil,
               date: nil,
               float: nil,
               has_many: nil,
               integer: nil,
               map: nil,
               map_of_integers: nil,
               naive_datetime: nil,
               naive_datetime_usec: nil,
               name: nil,
               percentage: nil,
               steamed_ham: nil,
               steamed_hams: [
                 %SteamedHams{
                   double_nested_schema: %{value: "works!"},
                   id: nil,
                   meat_type: "beef",
                   pickles: 2,
                   sauce_ratio: Decimal.new("0.5")
                 }
               ],
               throughs: %HasMany{
                 geese_to_feed: nil,
                 id: nil,
                 steamed_hams: nil,
                 through: %Through{}
               },
               time: nil,
               utc_datetime: nil,
               utc_datetime_usec: nil
             }
    end
  end
end
