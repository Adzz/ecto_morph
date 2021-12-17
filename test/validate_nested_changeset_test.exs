defmodule EctoMorph.ValidateNestedChangesetTest do
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

  test "an already invalid changeset remains invalid" do
    # PASS
    data = %{integer: false, aurora_borealis: %{probability: 4}}

    result =
      EctoMorph.generate_changeset(data, SchemaUnderTest)
      |> EctoMorph.validate_nested_changeset([:aurora_borealis], fn changeset ->
        changeset
        |> Ecto.Changeset.validate_number(:probability, less_than: 5)
      end)

    assert result.valid? == false
    assert result.errors == [integer: {"is invalid", [type: :integer, validation: :cast]}]
    assert result.changes.aurora_borealis.errors == []
  end

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

    # An already invalid changeset remains so if children are valid
    json = %{
      "thing" => false,
      "throughs" => %{"rad_level" => 16},
      "has_many" => [
        %{"steamed_hams" => [%{"pickles" => 6}, %{"pickles" => 6}]},
        %{"steamed_hams" => [%{"pickles" => 6}]},
        %{"steamed_hams" => [%{"pickles" => 6}, %{"pickles" => 6}]}
      ]
    }

    result =
      EctoMorph.generate_changeset(json, TableBackedSchema)
      |> EctoMorph.validate_nested_changeset([:has_many, :steamed_hams], fn changeset ->
        Ecto.Changeset.validate_number(changeset, :pickles, greater_than: 3)
      end)

    assert result.valid? == false
    assert result.errors == [thing: {"is invalid", [type: :string, validation: :cast]}]
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
      "Each field in the path_to_nested_changeset should point to a nested changeset. It looks like :not_a_field is not a field on Elixir.SchemaUnderTest.\n\nNB: You cannot validate through relations."

    # Can we alert people to the fact that the path is incorrect.
    # More importantly.... Should we???????????
    # One option is no, just do it right.
    # Other involve checking the field is in the schema_fields the changeset.?
    assert_raise(EctoMorph.InvalidPathError, error_message, fn ->
      EctoMorph.validate_nested_changeset(ch, [:not_a_field], & &1)
    end)

    error_message =
      "Each field in the path_to_nested_changeset should point to a nested changeset. It looks like :integer points to a change that isn't a nested changeset."

    # Pointing to a change, instead of a changeset
    assert_raise(EctoMorph.InvalidPathError, error_message, fn ->
      EctoMorph.validate_nested_changeset(ch, [:integer], & &1)
    end)

    error_message =
      "Each field in the path_to_nested_changeset should point to a nested changeset. It looks like :integer is not a field on Elixir.AuroraBorealis.\n\nNB: You cannot validate through relations."

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
      |> EctoMorph.validate_nested_changeset(
        [:steamed_hams],
        &Ecto.Changeset.validate_number(&1, :pickles, less_than: 5)
      )

    # There are no changes (as by default a SchemaUnderTest has no SteamedHams)
    assert result.valid? == true
    assert result.changes == %{}

    # Fail validation
    result =
      EctoMorph.generate_changeset(json, existing)
      |> EctoMorph.validate_nested_changeset([:steamed_hams], fn changeset ->
        changeset
        # Because on_replace is set to delete the changeset is always valid.
        |> Ecto.Changeset.validate_number(:pickles, greater_than: 55)
      end)

    assert result.valid? == true

    [first, second] = result.changes.steamed_hams
    # Because on_replace is set to delete the changeset is always valid.
    assert first.valid? == true
    assert second.valid? == true
    assert first.errors == []
    assert first.action == :replace
    assert second.action == :replace
  end

  test " when there are other changes, removing relations works" do
    # When there are other changes.
    json = %{"steamed_hams" => [], "integer" => 1}

    # Pass validation
    result =
      EctoMorph.generate_changeset(json, SchemaUnderTest)
      |> EctoMorph.validate_nested_changeset(
        [:steamed_hams],
        &Ecto.Changeset.validate_number(&1, :pickles, less_than: 5)
      )

    # There are no changes (as by default a SchemaUnderTest has no SteamedHams)
    assert result.valid? == true
    assert result.changes == %{integer: 1}

    json = %{"steamed_hams" => [], "integer" => 1}

    existing = %SchemaUnderTest{
      id: "1",
      steamed_hams: [
        %SteamedHams{id: "1", pickles: 10},
        %SteamedHams{id: "2", pickles: 12}
      ]
    }

    # Pass validation
    result =
      EctoMorph.generate_changeset(json, existing)
      |> EctoMorph.validate_nested_changeset(
        [:steamed_hams],
        &Ecto.Changeset.validate_number(&1, :pickles, less_than: 5)
      )

    # There are no changes (as by default a SchemaUnderTest has no SteamedHams)
    assert result.valid? == true

    assert %{
             integer: 1,
             steamed_hams: [steamed_changes_1, steamed_changes_2]
           } = result.changes

    assert steamed_changes_1.changes == %{}
    assert steamed_changes_1.action == :replace
    assert steamed_changes_1.valid? == true
    assert steamed_changes_1.errors == []

    assert steamed_changes_2.changes == %{}
    assert steamed_changes_2.action == :replace
    assert steamed_changes_2.valid? == true
    assert steamed_changes_2.errors == []
  end

  test "Pointing to an empty list is allowed" do
    # When there are other changes.
    json = %{"steamed_hams" => [], "integer" => 1}

    result =
      EctoMorph.generate_changeset(json, HasMany)
      |> Ecto.Changeset.put_assoc(:steamed_hams, [])
      |> EctoMorph.validate_nested_changeset(
        [:steamed_hams],
        &Ecto.Changeset.validate_number(&1, :pickles, less_than: 5)
      )

    assert result.valid? == true
    assert result.changes == %{steamed_hams: []}
  end

  test "has_one that has_one no changes to validate" do
    # when invalid changeset gets validated we remain invalid
    result =
      %{
        thing: false,
        has_one: %{steamed_ham: %{double_nested_schema: %{value: "This is a string"}}}
      }
      |> EctoMorph.generate_changeset(TableBackedSchema)
      |> EctoMorph.validate_nested_changeset(
        [:has_one, :steamed_ham, :double_nested_schema],
        & &1
      )

    assert result.valid? == false
    assert result.errors == [{:thing, {"is invalid", [type: :string, validation: :cast]}}]

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
