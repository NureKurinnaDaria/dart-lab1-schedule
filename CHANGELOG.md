## 2.0.0

- Restructured into a package: implementation in `lib/src`, facade
  `lib/lab4_schedule.dart`, entry points in `bin/`.
- Added manual JSON serialization (`Lesson.toJson`, `Lesson.fromJson`) and
  `LessonFileStorage` for the schedule file.
- Added streaming CSV reader (`readLessonsFromCsv`).
- Added command-line application on `args`: `import`, `report`, `holidays`.
- Added `HolidayClient` for the Nager.Date API with three failure levels.
- Added HTTP service on `shelf`: `GET /items`, `GET /items/<id>`,
  `POST /items`, request logging middleware.
- Added dependencies: `path`, `args`, `http`, `shelf`, `shelf_router`.
- Added `public_member_api_docs` lint; documented the public API.
- Removed duplicated weekday names: `Weekday` is the single source.
- Tests: 15 -> 68.

## 1.0.0

- Initial version (labs 1-3).
