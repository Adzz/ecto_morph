defmodule EctoMorphTest do
  use ExUnit.Case

  defmodule CustomType do
    @behaviour Ecto.Type

    @impl true
    def type, do: :map

    @impl true
    def cast(thing), do: {:ok, thing}

    @impl true
    def dump(_), do: raise("This will never be called")

    @impl true
    def load(_), do: raise("This will never be called")
  end

  defmodule SteamedHams do
    use Ecto.Schema

    embedded_schema do
      field(:meat_type, :string)
      field(:pickles, :integer)
      field(:sauce_ratio, :decimal)
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

      embeds_many(:steamed_hams, SteamedHams)
      embeds_one(:aurora_borealis, AuroraBorealis)

      field(:cutom_type, CustomType)
    end
  end

  describe "to_struct/2" do
    test "Converts the decoded JSON into a struct of the provided schema, casting the values appropriately" do
      json = %{
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
          %{"meat_type" => "chicken", "pickles" => 1, "sauce_ratio" => "0.7"}
        ],
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        },
        "cutom_type" => %{"a" => "b"},
        "field_to_ignore" => "ensures we just ignore fields that are not part of the schema"
      }

      {:ok, schema_under_test = %SchemaUnderTest{}} = EctoMorph.to_struct(json, SchemaUnderTest)

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
               %SteamedHams{meat_type: "beef", pickles: 2, sauce_ratio: Decimal.new("0.5")},
               %SteamedHams{meat_type: "chicken", pickles: 1, sauce_ratio: Decimal.new("0.7")}
             ]
    end
  end
end
