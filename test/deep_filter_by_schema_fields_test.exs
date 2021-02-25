defmodule EctoMorph.DeepFilterBySchemaFieldsTest do
  use ExUnit.Case, async: false

  describe "deep_filter_by_schema_fields/2" do
    test "we filter the data by all of the fields in the schema and its embeds_one relation" do
      data = %{
        binary_id: 1,
        ignored: "not a fields",
        filltered: "this is filtered",
        aurora_borealis: %{
          location: "Kitchen",
          probability: Decimal.new("0.001"),
          actually_a_fire?: false,
          ignored: true
        }
      }

      assert EctoMorph.deep_filter_by_schema_fields(data, SchemaUnderTest) == %{
               aurora_borealis: %{
                 actually_a_fire?: false,
                 location: "Kitchen",
                 probability: Decimal.new("0.001")
               },
               binary_id: 1
             }
    end

    test "works for an embeds_many" do
      data = %{
        binary_id: 1,
        ignored: "not a fields",
        filltered: "this is filtered",
        steamed_hams: [
          %{
            meat_type: "beef",
            pickles: 2,
            sauce_ratio: Decimal.new("0.5"),
            double_nested_schema: nil
          }
        ]
      }

      assert EctoMorph.deep_filter_by_schema_fields(data, SchemaUnderTest) == %{
               binary_id: 1,
               steamed_hams: [
                 %{
                   double_nested_schema: nil,
                   meat_type: "beef",
                   pickles: 2,
                   sauce_ratio: Decimal.new("0.5")
                 }
               ]
             }
    end

    test "has_many" do
      data = %{
        # This should just be ignored?
        throughs: %{"rad_level" => 16},
        has_many: [
          %{steamed_hams: [%{pickles: 1}, %{pickles: 2}]},
          %{steamed_hams: [%{pickles: 1}]},
          %{steamed_hams: [%{pickles: 4}, %{pickles: 5}]}
        ]
      }

      result = EctoMorph.deep_filter_by_schema_fields(data, TableBackedSchema)

      assert result == %{
               has_many: [
                 %{steamed_hams: [%{pickles: 1}, %{pickles: 2}]},
                 %{steamed_hams: [%{pickles: 1}]},
                 %{steamed_hams: [%{pickles: 4}, %{pickles: 5}]}
               ],
               throughs: %{"rad_level" => 16}
             }
    end

    test "round trip - basically makes a map without the meta keys (including virtual and through)" do
      data = %TableBackedSchema{test: "hi"}
      result = EctoMorph.deep_filter_by_schema_fields(data, TableBackedSchema)
      assert Map.drop(data, [:__meta__, :__struct__]) == result
    end

    test "works for arbitrary nesting" do
      data = %{
        binary_id: 1,
        ignored: "not a fields",
        filltered: "this is filtered",
        has_one: %{hen_to_eat: 15, ignored: "wut"},
        steamed_hams: [
          %{
            meat_type: "beef",
            pickles: 2,
            sauce_ratio: Decimal.new("0.5"),
            double_nested_schema: %{value: "works!"}
          }
        ]
      }

      assert EctoMorph.deep_filter_by_schema_fields(data, SchemaUnderTest) == %{
               binary_id: 1,
               steamed_hams: [
                 %{
                   double_nested_schema: %{value: "works!"},
                   meat_type: "beef",
                   pickles: 2,
                   sauce_ratio: Decimal.new("0.5")
                 }
               ]
             }
    end

    test "Nested Structs all work well" do
      data = %OverlapAndSome{
        binary_id: 1,
        ignored: "not a fields",
        filltered: "this is filtered",
        has_many: nil,
        throughs: [%HasMany{steamed_hams: nil, through: %Through{}}],
        steamed_hams: [
          %SteamedHams{
            meat_type: "beef",
            pickles: 2,
            sauce_ratio: Decimal.new("0.5"),
            double_nested_schema: %{value: "works!"}
          }
        ]
      }

      result = EctoMorph.deep_filter_by_schema_fields(data, SchemaUnderTest)

      assert result == %{
               array_of_ints: nil,
               aurora_borealis: nil,
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
               steamed_ham: nil,
               has_many: nil,
               throughs: [%{id: nil, steamed_hams: nil}],
               steamed_hams: [
                 %{
                   id: nil,
                   double_nested_schema: %{value: "works!"},
                   meat_type: "beef",
                   pickles: 2,
                   sauce_ratio: Decimal.new("0.5")
                 }
               ],
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

      result = EctoMorph.deep_filter_by_schema_fields(data, SchemaUnderTest)

      assert result == %{
               array_of_ints: nil,
               aurora_borealis: nil,
               binary: nil,
               binary_id: 1,
               boolean: nil,
               date: nil,
               float: nil,
               integer: nil,
               map: nil,
               map_of_integers: nil,
               naive_datetime: nil,
               naive_datetime_usec: nil,
               name: nil,
               percentage: nil,
               steamed_ham: nil,
               has_many: nil,
               throughs: %{
                 geese_to_feed: nil,
                 id: nil,
                 steamed_hams: nil,
                 through: %{id: nil, rad_level: nil}
               },
               steamed_hams: [
                 %{
                   id: nil,
                   double_nested_schema: %{value: "works!"},
                   meat_type: "beef",
                   pickles: 2,
                   sauce_ratio: Decimal.new("0.5")
                 }
               ],
               time: nil,
               utc_datetime: nil,
               utc_datetime_usec: nil
             }
    end
  end
end
