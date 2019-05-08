# Simplifying casting data

Let’s imagine we make a call to an external API and we get a response that looks something like this:

```elixir
response = %{
  "meat_type" => "medium rare",
  "pickles" => false,
  "collection_date" => "2019–11–04"
}
```

We want to turn that into a struct so that we can do things like implement protocols for it or even just coerce values into a type that we can rely on later. The simplest way we could do that is like this:

```elixir
defmodule SteamedHam do
  defstruct [:meat_type, :pickles, :collection_date]
end

struct(SteamedHam, response)
```

The struct function selects only the fields defined in the schema, so if we use it we are returned something that looks like this:

```elixir
%SteamedHam{
  meat_type: "medium rare",
  pickles: false,
  collection_date: "2019-11-04"
}
```

Now imagine in our code somewhere we want to work out the expiry date:

```elixir
def expiry_date(%SteamedHam{collection_date: collection_date}) do
  Date.add(collection_date, 3)
end
```

Except when we call it:

```elixir
*** (FunctionClauseError) no function clause matching in Date.add/2
```

Notice the problem? Our collection_date in our struct is not a date it is a string. It is a string because our API call returned us json, and json does not have a concept of a date object (they are represented as strings). What we want really is a way to specify up front the types of the steamed ham struct fields. That way we can rely on those types throughout the rest of our program. So we use Ecto:

```elixir
defmodule SteamedHam do
  use Ecto.Schema

  embedded_schema do
    field(:meat_type, :string)
    field(:pickles, :boolean)
    field(:collection_date, :date)
  end
end
```

So far this is a nice signal to other developers, but it doesn’t actually enforce anything. Our date string is still a string if we use struct:

```elixir
response = %{
  "meat_type" => "medium rare",
  "pickles" => false,
  "collection_date" => "2019–11–04"
}
steamed_ham = struct(SteamedHam, response)

# returns us this:

%SteamedHam{
  meat_type:"medium rare",
  pickles: false,
  collection_date: "2019–11–04"
}
```

Okay so instead let’s write a new function:

```elixir
def new(data = %{collection_date: collection_date}) do
  struct(
    SteamedHam,
    %{data | collection_date: Date.from_iso8601!(collection_date)}
  )
end
```

This is okay, especially with just one field, or just a few fields that need coercion. But imagine if we had lots of structs and lots of data — we’d need to keep track of which fields in each of the structs need coercing. Worse than that we’ve already defined exactly what we want each field to be in the definition of the Ecto Schema!

So what we could do is use that schema to figure our dynamically which fields should be what. Ecto allows us to introspect the schema (they call it reflection) like this:

```elixir
SteamedHam.__schema__(:fields)
```

That will return us a list of all non-virtual field names for the given schema. We can also do this:

```elixir
SteamedHam.__schema__(:type, :collection_date)
```

That will return us the type of a given field, in this case :date . If we combine the two we can do something like this:

```elixir
type_mappings =
  for field <- SteamedHam.__schema__(:fields), into: %{} do
    {field, SteamedHam.__schema__(:type, field)}
  end
```

This will return us a map that for the SteamedHam schema looks like this:

```elixir
%{
  meat_type: :string,
  pickles: :boolean,
  collection_date: :date,
  id: :binary_id
}
```

Now we can use that map to tell us what each field in the schema should be casted to. We do that by iterating through the key / value pairs in our API response and for each one, turn the key into an atom, use that atom to look up the type of value the value in the response should be, then casting that value. It might be easier to just show you:

```elixir
type_mappings =
  for field <- SteamedHam.__schema__(:fields), into: %{} do
    {field, SteamedHam.__schema__(:type, field)}
  end

casted_data =
  for {key, value} <- response, into: %{} do
    atomised_key = String.to_existing_atom(key)
    {atomised_key, cast_value(value, type_mappings[atomised_key])}
  end

def cast_value(value, :date) when is_binary(value) do
  Date.from_iso8601!(value)
end

def cast_value(value, _), do: value
```

This will essentially iterate through our API response data and cast the date field to be an actual elixir date and leave the rest as is. Now we can keep adding different cases for our cast_value function to handle any other casting we might want, for example turning a string integer to an Integer:

```elixir
def cast_value(value, :integer) when is_binary(value) do
  String.to_integer(value)
end
```

Hopefully by now you are thinking BUT WHY WOULD YOU WANT TO DO THAT?! Introspecting Ecto Schemas feels a bit weird — and it is unnecessary. Ecto gives us all of this power for free, with changesets!

Let’s look at the exact same idea, but using changesets:

```elixir
response = %{
  "meat_type" => "medium rare",
  "pickles" => false,
  "collection_date" => "2019–11–04"
}

Ecto.Changeset.cast(
  %SteamedHam{}, response, SteamedHam.__schema__(:fields)
)

# Returns:

%Ecto.Changeset{
  action: nil,
  changes: %{
    collection_date: ~D[2019–11–04],
    meat_type: "medium rare",
    pickles: false
  },
  errors: [],
  data: %SteamedHam{},
  valid?: true
}
```

The date gets coerced to a date automatically, and any invalid values get put into the changeset as errors. This is super awesome because we can use that to decide what we want to do in each case. For example:

```elixir
response = %{
  "meat_type" => "medium rare",
  "pickles" => false,
  "collection_date" => "2019–11–04"
}

Ecto.Changeset.cast(
  %SteamedHam{},
  response,
  SteamedHam.__schema__(:fields)
)
|> make_struct()

defp make_struct(changeset = %{errors: []}) do
  {:ok, Ecto.Changeset.apply_changes(changeset)}
end

defp make_struct(changeset) do
  {:error, changeset}
end
```

Okay so this is really good for simple fields, but now let’s look at relations. Imagine we define the following schema:

```elixir
defmodule DinnerGuest do
  use Ecto.Schema

  embedded_schema do
    field(:name, :string)
    embeds_many(:steamed_hams, SteamedHam)
    embeds_one(:aurora_borealis, AuroraBorealis)
  end
end
```

This schema says we have dinner guests which have many steamed_hams and one aurora_borealis. An example might look like this:

```elixir
%DinnerGuest{
  name: "Super Nintendo Chalmers",
  steamed_hams: [
    %SteamedHam{
      pickles: false,
      meat_type: "Rare",
      collection_date: ~D[2019–05–05]
    },
    %SteamedHam{
      pickles: true,
      meat_type: "burnt",
      collection_date: ~D[2019–05–05]
    }
  ],
  aurora_borealis: %AuroraBorealis{
    location: "Kitchen",
    probability: 0.1,
    actually_a_fire?: true
  }
}
```

Now we have to be a bit careful because the embedded relations need to be treated differently from the usual fields. If we want the same casting behaviour as before for our relations, we need to use cast_embed. cast_embed does the same thing as the Ecto.Changeset.cast function above, but, you guessed it, for embedded_schemas. Let’s try using it now, imagine this is the response from our API call that we want to serialize into structs:

```elixir
response = %{
    "name" => "Super Nintendo Chalmers",
    "steamed_hams" => [
      %{
        "meat_type" => "medium rare",
        "pickles" => false,
        "collection_date" => "2019–11–04"
      },
      %{
        "meat_type" => "rare",
        "pickles" => true,
        "collection_date" => "2019–11–04"
      }
    ],
  "aurora_borealis" => %{
    "location" => "Kitchen",
    "probability" => 1.3,
    "actually_a_fire?" => true
  }
}

# Let's try and use cast to serialize it for us:

Ecto.Changeset.cast(
  %DinnerGuest{},
  response,
  DinnerGuest.__schema__(:fields)
)
```

This blows up because that last argument to cast is a list of fields that we want to allow inside the response, during casting. Above we have said, let all the fields through, but we don’t want all the fields, we want only all of the fields that are not embeds; in this case the name field:

```elixir
Ecto.Changeset.cast(%DinnerGuest{}, response, [:name])
```

Now this hasn’t failed, but it has also ignored the embedded fields completely, which is not awesome. To change that we need to use cast_embed for each of the embedded schemas. But there is a slight problem, Ecto wants to know for those embedded structs, which fields we should allow, but cast_embed doesn’t take a list of fields the same way cast does. Instead you can do one of two things. If you give no other arguments and just do this:

```elixir
Ecto.Changeset.cast(%DinnerGuest{}, response, [:name])
|> Ecto.Changeset.cast_embed(:steamed_hams)
|> Ecto.Changeset.cast_embed(:aurora_borealis)
```

then Ecto will call SteamedHam.changeset/2 for every steamed ham in the response, and will call AuroraBorealis.changeset/2 for the data under the aurora_borealis key in the response. This is fine if you have defined those functions, but less good if you don’t want to put a changeset function on the schema.

Instead then you can provide a with option which is a function that gets two arguments: an empty struct (of whatever the embedded schema is), and the relevant data from the response. So for the SteamedHam, we would get an empty %SteamedHam{} as the first arg, then data from the first item in the list under the steamed_hams key in our response. Then it would be called again with the second item in the list as the last argument.

We can use these arguments to define our own functions that do just exactly what we did in our cast function — namely filter our irrelevant fields, and cast the rest of the data accordingly. That would look like this:

```elixir
Ecto.Changeset.cast(%DinnerGuest{}, response, [:name])
|> Ecto.Changeset.cast_embed(
  :steamed_hams,
  with: fn steamed_ham = %{__struct__: schema}, data ->
    Ecto.Changeset.cast(
      steamed_ham,
      data,
      schema.__schema__(:fields)
    )
  end
)
|> Ecto.Changeset.cast_embed(
  :aurora_borealis,
  with: fn aurora_borealis = %{__struct__: schema}, data ->
    Ecto.Changeset.cast(
      aurora_borealis,
      data,
      schema.__schema__(:fields)
    )
  end
)
```

Now we are getting somewhere! If we pipe that all into Ecto.Changeset.apply_changes we get exactly what we want, which is our casted, validated structs:

```elixir
%DinnerGuest{
  aurora_borealis: %AuroraBorealis{
    actually_a_fire?: true,
    location: "Kitchen",
    probability: 1.3
  },
  name: "Super Nintendo Chalmers",
  steamed_hams: [
    %SteamedHam{
      collection_date: ~D[2019–11–04],
      meat_type: "medium rare",
      pickles: false
    },
    %SteamedHam{
      collection_date: ~D[2019–11–04],
      meat_type: "rare",
      pickles: true
    }
  ]
}
```

So let’s review. This is nice, because we’ve been able to use our schemas to define types for fields, validate their types and cast them if possible to create structs that we can use in our programmes. But the journey has been a little rocky, we’ve had to know a lot about a lot of things, and those things can quickly become repetitive. What if we could make all of this dynamic, and automatic?

EctoMorph gives us some syntactic sugar for the same process we just stepped through. It simplifies all of the above to allow us to do this:

```elixir
EctoMorph.to_struct(response, DinnerGuest)
```
