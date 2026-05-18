# Settlement PDF Export and Expense Cycles

## PDF export

The Expense Settlement screen includes a **Download PDF** / **تحميل PDF** action.
The app generates the current settlement report and opens Android's native
share/print sheet through the `printing` package. The report includes the app
name, network name, currency, generation time, total expenses, member totals,
settlement transfers, and the Karamix Labs footer.

The PDF renderer embeds the bundled Noto Naskh Arabic regular and bold fonts
from `assets/fonts` for the full document. Arabic reports are generated with
RTL text direction, real Arabic labels, clean member/result wording, and a
professional card/table layout so Android PDF viewers, Google Drive preview,
Telegram, and WhatsApp do not show square placeholder glyphs.

## New expense cycle approval

The settlement screen also includes **Start New Cycle** / **بدء مصروف جديد**.
This creates a reset request instead of deleting data. The requester is counted
as approved immediately, and the approval snapshot is the member list that
existed when the request was created. Members who join later are not required
for that pending request.

Expenses remain active until every required member approves. While pending, the
screen shows who requested the reset, who approved, who is still pending, and an
approve button for members who have not approved.

After unanimous approval:

- the current cycle is marked closed
- old expenses are archived by cycle instead of hard-deleted
- a new active cycle is created
- dashboard and settlement totals show the new empty active cycle
- all members receive a "new cycle started" notification

## Local vs cloud mode

Local mode stores cycles, reset requests, approvals, archived expenses, and
notifications in SharedPreferences. It affects only the current device's local
data, matching the rest of local mode.

Supabase mode stores the same flow centrally in:

- `expense_cycles`
- `expense_reset_requests`
- `expense_reset_approvals`
- `expenses.cycle_id`
- `expenses.archived_at`
- `network_notifications.kind`
- `network_notifications.reset_request_id`

Existing expenses without `cycle_id` remain compatible and are treated as part
of the current active cycle until a reset archives them.
