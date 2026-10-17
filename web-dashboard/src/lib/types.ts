export interface Network {
  id: string;
  name: string;
  currency_code: string;
  currency_symbol: string;
  created_by_member_id: string | null;
  created_at: string;
}
export interface Member {
  id: string;
  network_id: string;
  name: string;
  avatar_initials: string | null;
  avatar_color: string | null;
  created_at: string;
}
export interface Expense {
  id: string;
  network_id: string;
  paid_by_member_id: string | null;
  paid_by_member_name: string;
  added_by_member_id: string | null;
  added_by_member_name: string;
  amount_cents: number;
  note: string | null;
  cycle_id: string | null;
  archived_at: string | null;
  client_generated_id: string | null;
  created_at: string;
}
export interface Cycle {
  id: string;
  network_id: string;
  cycle_number: number;
  status: "active" | "pending_reset" | "closed";
  started_at: string;
  closed_at: string | null;
}
export interface ResetRequest {
  id: string;
  network_id: string;
  cycle_id: string;
  requested_by_member_id: string;
  requested_by_member_name: string;
  required_member_ids: string[];
  status: "pending" | "completed" | "cancelled";
}
export interface Approval {
  id: string;
  reset_request_id: string;
  member_id: string;
}
export interface Notification {
  id: string;
  actor_member_name: string;
  kind: string;
  amount_cents: number;
  note_snippet: string | null;
  is_read: boolean;
  created_at: string;
}
export interface Snapshot {
  network: Network;
  me: Member;
  members: Member[];
  expenses: Expense[];
  cycles: Cycle[];
  requests: ResetRequest[];
  approvals: Approval[];
  notifications: Notification[];
}
