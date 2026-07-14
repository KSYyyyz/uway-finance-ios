# Changelog

## 0.9.0 - 2026-07-14

- Accept the optional `financeSchemaVersion` returned by backend 0.9.0 while remaining compatible with 0.8.x health responses.
- Add an explicit backend capability contract: Finance Domain V2 is currently a server-side mirror, while iOS continues to read and write through `/api/state`.
- Preserve legacy JSON amount fields while converting network/domain amounts to integer cents at the Codable boundary.
- Show the detected finance schema and active compatibility mode in Profile.
- Keep Import Harness decisions restricted to `accepted`, `review` and `rejected`; accepted analysis still does not directly create a formal V2 business record or voucher.

## 0.8.0 - 2026-07-13

- Added the first native SwiftUI client, session restoration, state sync, CSV import analysis and reserved OCR/document boundaries.
