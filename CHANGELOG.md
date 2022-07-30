# Changelog for version 0.1

## 0.1.26

Updates to work with latest version of Ecto.


## 0.1.25

### Bug Fix

The previous release inadvertently changed the behaviour of `filter_by_schema_fields` by including associations by default. Previously that wasn't the case. So now we add back in an option to exclude any associations when filtering by schema fields.

## 0.1.24

### Enhancement

Adds a new function: `EctoMorph.validate_required/2` which allows you to specify a list of arbitrarily nested fields which will be marked as required. You may also mark relations and embeds as required. This lets you generate the changeset and then mark stuff as required, whereas ecto forces you to provide that option on cast_assoc / cast_embed. See the docs for examples.

Adds an option to `filter_by_schema_fields` and `deep_filter_by_schema_fields` which allows you to filter nillify not loaded relations.


## 0.1.23

### Enhancement

* Updates ex_doc.

### Bug Fix

* [validate_nested_changeset] - previously we were marking the parent as valid if the nested changeset was valid. This was incorrect if the parent was already invalid. This has now been fixed.
