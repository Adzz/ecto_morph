defmodule EctoMorph.ValidateRequiredRelationTest do
  use ExUnit.Case, async: false

  test "relation pointed to is marked as required" do
    EctoMorph.generate_changeset(json, SchemaUnderTest)
    |> EctoMorph.validate_required([:steamed_hams])
    |> IO.inspect(limit: :infinity, label: "")
  end

  test "invalid changeset when required is missing" do
  end

  test "valid changeset when required relation is in data" do
  end

  test "valid changeset when required relation is in changes" do
  end

  test "we can point to deep relations, and all relations above it will also be required" do
  end

  defp json() do
    %{
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
  end
end

# unit test each component
# integration test - test each fn gets called with the expected args
# Maybe an integration test
