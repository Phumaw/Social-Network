# Bug / Fix Log

## Create-post screen — 2026-10-20

| Issue | Fix | Verification |
|---|---|---|
| Image selection and form fields had no explicit accessible labels; the image affordance lacked a screen-reader hint. | Added field labels, image-picker semantics, preview-image description, removal tooltip, and accessible progress labels. | Accessibility widget tests cover labels, hints, and preview description. |
| Users could edit the draft or change its image during an upload, then lose those edits when the request succeeded. | Disable the text fields and image controls while saving; retain the draft after a failed request. | Widget tests cover in-flight locking and failed-upload draft retention. |
| A user could reopen image selection while a picker request was active, and had no visible progress indication. | Prevent overlapping picker requests and show accessible picker progress; restore the picker after cancellation or failure. | Widget tests cover gallery/camera selection, cancellation, and picker errors. |
| Post submission had no focused automated coverage for validation, successful submission, or service failures. | Added injectable picker/service dependencies and widget tests for form and request behavior. | `test/screens/post/create_post_screen_test.dart` contains 14 widget cases. |

## Social Network rebrand — 2026-10-20

| Issue | Fix | Verification |
|---|---|---|
| Login only accepted a username in the interface, and the client/server contract did not use an explicit email field. | Added email validation and email/password sign-in; the API accepts email while retaining username compatibility for older clients. | Widget tests verify invalid email rejection and email/password submission; backend JavaScript syntax check passed. |
| Food-specific branding and light surfaces persisted across screens and platform launch assets. | Rebranded the app as Social Network, generalized feed/post copy, added a social-network mark and platform icons, and applied dark styling to app and launch surfaces. | All Flutter tests and analyzer passed; Android debug APK built; iOS/macOS icon assets validated. |
| Community pages were not discoverable from primary screens. | Added shortcuts to groups and communities from the feed and discovery search. | Flutter analyzer and full test suite passed. |

## Accessibility and search stability — 2026-10-20

| Issue | Fix | Verification |
|---|---|---|
| Overlapping searches could finish out of order and let an older response or error replace the latest query state. | Added request sequencing and invalidated pending requests as soon as the query changes; made search services injectable for deterministic testing. | Search widget tests cover out-of-order responses, debounce, retry/error, query modes, and hashtag normalization. |
| Search, registration, password visibility, reaction, private-account, and group-creation controls did not consistently expose their purpose to assistive technology. | Added accessible labels, semantics, and tooltips to the affected controls. | Search widget tests verify accessible search labels and the private-account tooltip; analyzer and full test suite validate the changes. |
| Search behavior had no focused regression coverage for common modes and asynchronous edge cases. | Added 12 search-screen widget tests and adjusted the registration test to identify the password field by its field label rather than duplicate visible/input labels. | `test/screens/search/search_screen_test.dart` contains 12 cases; full Flutter test suite and analyzer pass. |
