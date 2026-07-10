# Hatch2Revenue

A poultry farm management app built with Flutter. Tracks birds from day-old
chicks to layer stage with vaccination scheduling, feed monitoring, egg
production, mortality logging, and financial analysis.

## Features

- **Batch lifecycle** — track breed, entry date, age, and stage; deleting a
  batch cascades to all its linked records.
- **Vaccination scheduler** — auto-generates the standard vaccination program
  (Marek's, Newcastle, Gumboro, etc.) when a batch is created, with local
  notification reminders.
- **Feed monitor** — daily consumption logs plus full stock inventory
  (add/edit/delete with expiry tracking, low-stock alerts, and days-left
  estimates); costs auto-post to Financials.
- **Egg production** — daily tallies with Hen-Day %, sales auto-post as income.
- **Mortality log** — deaths update the batch's live bird count automatically.
- **Financial dashboard** — income vs. expenses, PDF report export.
- **Analytics** — laying rate, mortality rate, FCR, feed cost per egg, and a
  7-day egg production forecast.
- **Data** — everything persists to a local SQLite database; one-tap CSV
  export of all records from the Farm Profile screen, shareable via
  WhatsApp/email, and the PDF farm report can be printed or shared.
- **Day & night mode** — toggle from the sun/moon button in the app bar;
  the choice is remembered across restarts.

## Getting started

```bash
flutter pub get
flutter run
```

Desktop (Windows/Linux) is supported via `sqflite_common_ffi`.

## Tests

```bash
flutter test
```
