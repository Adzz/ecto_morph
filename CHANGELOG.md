# Changelog for version 0.X

## 0.1.23

### Enhancement

* Updates ex_doc.

### Bug Fix

* [validate_nested_changeset] - previously we were marking the parent as valid if the nested changeset was valid. This was incorrect if the parent was already invalid. This has now been fixed.
