# BigQuery Analytics

MediFlow mirrors operational Firestore events into BigQuery from Cloud Functions.

## Dataset

Default dataset: `mediflow_analytics`

Override with function environment variables:

- `BQ_DATASET`
- `BQ_LOCATION`

## Tables

- `ai_decisions`: forecast and stock-analysis decisions, model output, reasoning, inputs.
- `transfer_requests`: restock and redistribution request lifecycle rows.
- `inventory_snapshots`: inventory stock-health snapshots on medicine writes.
- `usage_analytics`: flattened daily usage rows per medicine.
- `audit_events`: before/after JSON for request, inventory, usage, and AI decision events.

## Deploy Notes

Enable the BigQuery API in the Firebase/GCP project and make sure the Cloud Functions service account can create datasets/tables and insert rows. The functions create the dataset and tables lazily on first event.

Typical roles:

- `BigQuery Data Editor`
- `BigQuery Job User`

Deploy functions after dependencies are installed:

```bash
cd functions
npm install
firebase deploy --only functions
```
