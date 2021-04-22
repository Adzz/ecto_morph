defmodule EctoMorph.ValidateRequiredTest do
  use ExUnit.Case, async: false

  describe "embeds_many" do
    test "not in changes or data is invalid" do
      json = %{
        "binary_id" => "this_is_a_binary_id",
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        }
      }

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: []})
        |> EctoMorph.validate_required([:steamed_hams])

      assert ch.valid? == false
      assert ch.errors == [{:steamed_hams, {"can't be blank", [validation: :required]}}]
    end

    test "when in data is not invalid" do
      json = %{
        "binary_id" => "this_is_a_binary_id",
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        }
      }

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: [%SteamedHams{}]})
        |> EctoMorph.validate_required([:steamed_hams])

      assert ch.valid? == true
      assert ch.errors == []
    end

    test "when in changes is not invalid" do
      json = %{
        "steamed_hams" => [
          %{"meat_type" => "beef", "pickles" => 2, "sauce_ratio" => "0.5"},
          %{
            "meat_type" => "chicken",
            "pickles" => 1,
            "sauce_ratio" => "0.7",
            "double_nested_schema" => %{"value" => "works!"}
          }
        ]
      }

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: []})
        |> EctoMorph.validate_required([:steamed_hams])

      assert ch.valid? == true
      assert ch.errors == []
    end
  end

  describe "embeds_one" do
    test "not in changes or data is invalid" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_required([:aurora_borealis])

      assert ch.valid? == false
      assert ch.errors == [{:aurora_borealis, {"can't be blank", [validation: :required]}}]

      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{aurora_borealis: nil})
        |> EctoMorph.validate_required([:aurora_borealis])

      assert ch.valid? == false
      assert ch.errors == [{:aurora_borealis, {"can't be blank", [validation: :required]}}]
    end

    test "when in data is not invalid" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{aurora_borealis: %AuroraBorealis{}})
        |> EctoMorph.validate_required([:aurora_borealis])

      assert ch.valid? == true
      assert ch.errors == []
    end

    test "when in changes is not invalid" do
      json = %{
        "aurora_borealis" => %{
          "location" => "Kitchen",
          "probability" => "0.001",
          "actually_a_fire?" => false
        }
      }

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{})
        |> EctoMorph.validate_required([:aurora_borealis])

      assert ch.valid? == true
      assert ch.errors == []
    end
  end

  describe "has_one" do
    test "not in changes or data is invalid" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, TableBackedSchema)
        |> EctoMorph.validate_required([:has_one])

      assert ch.valid? == false
      assert ch.errors == [{:has_one, {"can't be blank", [validation: :required]}}]

      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %TableBackedSchema{has_one: nil})
        |> EctoMorph.validate_required([:has_one])

      assert ch.valid? == false
      assert ch.errors == [{:has_one, {"can't be blank", [validation: :required]}}]
    end

    test "when in data is not invalid" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %TableBackedSchema{has_one: %HasOne{}})
        |> EctoMorph.validate_required([:has_one])

      assert ch.valid? == true
      assert ch.errors == []
    end

    test "when in changes is not invalid" do
      json = %{
        "has_one" => %{
          "hen_to_eat" => "1"
        }
      }

      ch =
        EctoMorph.generate_changeset(json, %TableBackedSchema{})
        |> EctoMorph.validate_required([:has_one])

      assert ch.valid? == true
      assert ch.errors == []
    end
  end

  describe "has_many" do
    test "not in changes or data is invalid" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, SchemaUnderTest)
        |> EctoMorph.validate_required([:has_many])

      assert ch.valid? == false
      assert ch.errors == [{:has_many, {"can't be blank", [validation: :required]}}]

      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{has_many: []})
        |> EctoMorph.validate_required([:has_many])

      assert ch.valid? == false
      assert ch.errors == [{:has_many, {"can't be blank", [validation: :required]}}]

      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{has_many: nil})
        |> EctoMorph.validate_required([:has_many])

      assert ch.valid? == false
      assert ch.errors == [{:has_many, {"can't be blank", [validation: :required]}}]
    end

    test "when in data is not invalid" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{has_many: [%HasMany{}]})
        |> EctoMorph.validate_required([:has_many])

      assert ch.valid? == true
      assert ch.errors == []
    end

    test "when in changes is not invalid" do
      json = %{
        "has_many" => [
          %{
            "geese_to_feed" => 1
          }
        ]
      }

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{has_many: []})
        |> EctoMorph.validate_required([:has_many])

      assert ch.valid? == true
      assert ch.errors == []
    end
  end

  describe "nested fields" do
    test "not in changes or data is invalid" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: []})
        |> EctoMorph.validate_required(steamed_hams: :meat_type)

      assert ch.valid? == false
      assert ch.errors == [{:steamed_hams, {"can't be blank", [validation: :required]}}]

      json = %{"steamed_hams" => [%{"pickles" => 2, "sauce_ratio" => "0.5"}]}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: []})
        |> EctoMorph.validate_required(steamed_hams: :meat_type)

      assert ch.valid? == false
      [ch] = ch.changes.steamed_hams
      assert ch.errors == [{:meat_type, {"can't be blank", [validation: :required]}}]
    end

    test "has many double nest" do
      json = %{"binary_id" => "this_is_a_binary_id"}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: []})
        |> EctoMorph.validate_required(steamed_hams: [double_nested_schema: :value])

      assert ch.valid? == false
      assert ch.errors == [{:steamed_hams, {"can't be blank", [validation: :required]}}]

      json = %{"steamed_hams" => [%{"pickles" => 2, "sauce_ratio" => "0.5"}]}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: []})
        |> EctoMorph.validate_required(steamed_hams: [double_nested_schema: :value])

      assert ch.valid? == false
      [ch] = ch.changes.steamed_hams
      assert ch.errors == [{:double_nested_schema, {"can't be blank", [validation: :required]}}]

      json = %{"steamed_hams" => [%{"double_nested_schema" => %{}}]}

      ch =
        EctoMorph.generate_changeset(json, %SchemaUnderTest{steamed_hams: []})
        |> EctoMorph.validate_required(steamed_hams: [double_nested_schema: :value])

      assert ch.valid? == false
      [ch] = ch.changes.steamed_hams

      ch = ch.changes.double_nested_schema
      assert ch.errors == [{:value, {"can't be blank", [validation: :required]}}]
    end
  end

  # This is a private function but is public so that I can test it.
  describe "expand_path/1" do
    test "[:thing, thing: [okay: :then, if: :yes], and: :another]" do
      path = [:thing, thing: [okay: :then, if: :yes], and: :another]

      assert EctoMorph.expand_path(path) == [
               {[:thing, :if], [:yes]},
               {[:thing, :okay], [:then]},
               {[], [:thing]},
               {[:and], [:another]}
             ]
    end

    test "[and: :another]" do
      path = [and: :another]
      assert EctoMorph.expand_path(path) == [{[:and], [:another]}]
    end

    test "[:thing, thing: [okay: :then, if: :yes], and: [:another]]" do
      path = [:thing, thing: [okay: :then, if: :yes], and: [:another]]

      assert EctoMorph.expand_path(path) == [
               {[:thing, :if], [:yes]},
               {[:thing, :okay], [:then]},
               {[], [:thing]},
               {[:and], [:another]}
             ]
    end

    test "[:thing, :another, :last]" do
      path = [:thing, :another, :last]

      assert EctoMorph.expand_path(path) == [{[], [:thing, :another, :last]}]
    end

    test "[thing: [okay: :then, if: :yes], and: [:another]]" do
      path = [thing: [okay: :then, if: :yes], and: [:another]]

      assert EctoMorph.expand_path(path) == [
               {[:thing, :okay], [:then]},
               {[:thing, :if], [:yes]},
               {[:and], [:another]}
             ]
    end
  end
end
