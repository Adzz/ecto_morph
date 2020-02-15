defmodule EctoMorph.Validate do
  @moduledoc """
  EctoMorph.Validate allows you to perform Ecto validations on a subset of a given map of changes.

  Imagine you have a map of data that looks like this:
  ```elixir
      athlete = %{name: "Jeff Vader", medal: %{type: gold, championship_points: 30}}
  ```
  You can cast that data into a changeset like so:

  ```elixir
      %Athlete{}
      |> Ecto.Changeset.cast(
        %{name: "Jeff Vader", medal: %{type: "GOLD", championship_points_earned: 30}},
        [:name]
      ) |> Ecto.Changeset.cast_assoc(:medal,
        with: fn struct, changes ->
          Ecto.Changeset.cast(struct, changes, [:type, :championship_points_earned])
        end
      )
  ```
  Or using EctoMorph like this:
  ```elixir
      EctoMorph.generate_changeset(athlete, Athlete)
  ```

  Once you do that you will have a changeset that has a changeset inside it, which is great. However
  if you then want to do validations on that nested changeset, it becomes a little tricky. This module
  is designed to help you with that case. You can specify a path to the data that you wish to validate
  like so:
  ```elixir

      EctoMorph.generate_changeset(athlete, Athlete)
      |> EctoMorph.Validate.required([:name, medal: [:type, :championship_points_earned]])
  ```

  This will also work for has_many relations. This will ensure all of the medals given have a type
  and championship_points field.
  ```elixir

      athlete = %{
        name: "Jeff Vader",
        medals: [%{type: gold, championship_points: 30}}, %{type: silver, championship_points: 20}]
      }
      |> EctoMorph.generate_changeset(Athlete)
      |> EctoMorph.Validate.required([:name, medal: [:type, :championship_points_earned]])
  ```

  This is also completely backwards compatible with Ecto.
  """

  def change(changeset) do
  end
end
