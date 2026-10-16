# Engagements

One pseudonymous record per engagement, `eng-<yyyy>-<mm>-<4 lowercase letters or digits>.json` (schema: `../schemas/engagement.schema.json`). Records live only in an organization's **private** fork (`"scope": "organization"` in `../knowledge.json`); in this public repository the folder stays empty, and the guard fails if it isn't.

Never put the customer's name in the ID, the file or anywhere in `knowledge/`. The mapping from engagement ID to customer belongs in the organization's own engagement records.
