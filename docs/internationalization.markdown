Internationalization
====================

**Table of Contents**

- [Workflow](#workflow)
- [Translation.io](#translationio)
- [Conventions](#conventions)
    - [Views and Helpers](#views-and-helpers)
    - [Semantic completeness](#semantic-completeness)
    - [URL helpers and embedded links](#url-helpers-and-embedded-links)
    - [Mailers](#mailers)
    - [Controllers](#controllers)
    - [JavaScript](#javascript)
- [Pre-Deployment Translation Syncing](#pre-deployment-translation-syncing)

Workflow
--------

If you modify the English translation file [config/locales/en.yml](config/locales/en.yml), run:

```shell
bin/rake prepare_translations
```

before pushing to GitHub. This will normalize translation file formatting and
check for missing or unused keys.

Translation.io
--------------

We're using [translation.io](https://translation.io) to manage internationalization:
[translation.io/bikeindex/bike_index](https://translation.io/bikeindex/bike_index)

To contribute, sign up for an account there and ask to be added to the project
as a translator.

**Non-English translation files should be treated as read-only.**
We sync these with our translation.io project.


Conventions
-----------

### Views and Helpers

In the view layer (templates and helper modules), externalize strings using the
`I18n.t()` translation helper directly. Templates typically use the
["lazy" lookup][i18n-lazy] form.

### Semantic completeness

To aid translation, it's desirable to externalize strings in a form as close to
semantically complete as possible.

In particular, use coarse conditional branching in templates. Duplication of
user-facing copy is desirable whenever its alernative is to break up a string
into units that, in isolation, might lose their context or encode an assumption
about word order that doesn't hold in another language.

For example, instead of

```haml
- when = expedited ? "soon" : "eventually"
= "You'll #{when} receive your delivery"
```

prefer

```haml
- if expedited?
  = "You'll soon receive your delivery"
- else
  = "You'll eventually receive your delivery"
```

The former externalizes as

```yaml
soon: spoedig
youll_receive_delivery: U ontvangt %{wanneer} uw levering ontvangt
```

But the translation we'd want is:

```yaml
youll_soon_receive_delivery: U ontvangt binnenkort uw levering
```

### URL helpers and embedded links

Prefer URL helpers to hard-coded URLs. The former will forward the `locale`
query param when it's present.

Embedded links are typically translated separately and passed to an enclosing
[`html_safe` translation][i18n-html-safe] (note the `_html` suffix in the
translation key):

```haml
- logout_link = link_to t(".log_out"), session_path(redirect_location: 'new_user'), method: :delete
= t(".if_you_dont_want_that_to_be_the_case_html", logout_link: logout_link)
```

[i18n-lazy]: https://guides.rubyonrails.org/i18n.html#lazy-lookup
[i18n-html-safe]: https://guides.rubyonrails.org/i18n.html#using-safe-html-translations

### Mailers

Mailers are namespaced by mailer name, email name, and email format as follows
(note the `.text` and `.html` in the translation keys):

```yaml
# config/locales/en.yml

organization_invitation:
  html:
    you_are_a_member: "%{sender_name} has indicated that you are a member of %{org_name}."
  text:
    you_are_a_member: "%{sender_name} has indicated that you are a member of %{org_name}."
```

```haml
-# app/views/organized_mailer/organization_invitation.html.haml

%p= t(".html.you_are_a_member", sender_name: @sender.display_name, org_name: @organization.name)
```

```haml
-# app/views/organized_mailer/organization_invitation.text.haml

= t(".text.you_are_a_member", sender_name: @sender.display_name, org_name: @organization.name)
```

### Controllers

Controllers use the `translation` helper method defined in `ControllerHelpers`.
This method wraps `I18n.translate` and infers the scope in accordance with the
convention of scoping translations by their lexical location in the code base.

Both `:scope` and `:controller_method` can be overriden using the corresponding
keyword args. Note that base controllers should be passed `:scope` or
`:controller_method` explicitly. See the `translation` method docstring for
implementation details

```rb
# app/controllers/concerns/controller_helpers.rb

def translation(key, scope: nil, controller_method: nil, **kwargs)
  # . .
  scope ||= [:controllers, controller_namespace, controller_name, controller_method.to_sym]
  I18n.t(key, **kwargs, scope: scope.compact)
end
```


### JavaScript

Client-side translations are defined under the `:javascript` keyspace in `en.yml`.

```yml
# config/locales/en.yml

javascript:
  bikes_search:
```

The translation method can be invoked directly as `I18n.t()` and passed a
complete scope:

```jsx
<span className="attr-title">{I18n.t("javascript.bikes_search.registry")}</span>
```

Equivalently, a curried instance of `I18n.t` can be initiated locally (by
convention, bound to `t`) with the local keyspace set as needed:

```jsx
// app/javascript/packs/external_registry_search/components/ExternalRegistrySearchResult.js

const t = BikeIndex.translator("bikes_search");
// . . .
<span className="attr-title">{t("registry")}</span>
```

A client-side JS translations file is generated when the `prepare_translations`
rake task is run. See [PR #1353][pr-1353] for implementation details.

[pr-1353]: https://github.com/bikeindex/bike_index/pull/1353

Pre-Deployment Translation Syncing
----------------------------------

When building master, we check for un-synced translations and, if any are found,
stop the build and open a PR to master with the translation updates.

You'll want to merge this PR (delete the description) to trigger a new build and
retry deployment on master.

(See [#1100](https://github.com/bikeindex/bike_index/pull/1100) for details.)

To manually update the keys on translation.io, run
`bin/rake translation:sync_and_purge` (requires having an active API key locally).
