# Function privilege inventory (isolated local database)

Generated from the complete reviewed migration chain on 2026-10-17. No production data queried. This inventory must be compared with the production catalog read-only before rollout. Trigger functions are called by PostgreSQL, not granted as client RPCs. All functions below use fixed search paths; authorization notes and input contracts are in backend-hardening.md.

| Function/signature | Owner | Context | anon | authenticated | service_role |
| --- | --- | --- | --- | --- | --- |
| `private.maskan_finish_approval()` | postgres | DEFINER | no | no | no |
| `private.maskan_finish_reset_request()` | postgres | DEFINER | no | no | no |
| `private.maskan_guard_approval()` | postgres | INVOKER | no | no | no |
| `private.maskan_guard_cycle()` | postgres | INVOKER | no | no | no |
| `private.maskan_guard_expense()` | postgres | INVOKER | no | no | no |
| `private.maskan_guard_membership_change()` | postgres | DEFINER | no | no | no |
| `private.maskan_guard_notification_insert()` | postgres | INVOKER | no | no | no |
| `private.maskan_guard_request_delete()` | postgres | INVOKER | no | no | no |
| `private.maskan_legacy_password_hash(password_salt text, raw_password text)` | postgres | INVOKER | no | no | no |
| `private.maskan_lock_network(p_network_id uuid)` | postgres | INVOKER | no | no | no |
| `private.maskan_prepare_reset_request()` | postgres | INVOKER | no | no | no |
| `private.maskan_reject_credential_downgrade()` | postgres | INVOKER | no | no | no |
| `private.maskan_release_pending_cycle()` | postgres | DEFINER | no | no | no |
| `public.maskan_account_deletion_context()` | postgres | DEFINER | no | yes | no |
| `public.maskan_account_deletion_rate_limit_check()` | postgres | DEFINER | no | yes | no |
| `public.maskan_account_deletion_rate_limit_failure()` | postgres | DEFINER | no | yes | no |
| `public.maskan_approve_expense_reset(p_network_id uuid, p_reset_request_id uuid)` | postgres | DEFINER | no | yes | no |
| `public.maskan_authorize_account_deletion(p_auth_user_id uuid, p_token_hash text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_can_create_active_cycle(target_network_id uuid, target_cycle_number integer)` | postgres | DEFINER | no | yes | no |
| `public.maskan_claim_legacy_member(p_member_id uuid, p_member_password text)` | postgres | DEFINER | no | no | no |
| `public.maskan_claim_member(p_member_id uuid, p_claim_token text)` | postgres | DEFINER | no | yes | no |
| `public.maskan_complete_expense_cycle(p_network_id uuid, p_cycle_id uuid, p_reset_request_id uuid)` | postgres | DEFINER | no | yes | no |
| `public.maskan_create_network(p_network_id uuid, p_member_id uuid, p_network_name text, p_member_name text, p_network_password_hash text, p_network_password_salt text, p_member_password_hash text, p_member_password_salt text, p_currency_code text, p_currency_symbol text)` | postgres | DEFINER | no | no | no |
| `public.maskan_current_member_id()` | postgres | DEFINER | no | yes | no |
| `public.maskan_current_network_id()` | postgres | DEFINER | no | yes | no |
| `public.maskan_delete_account_data(p_deletion_token text, p_confirm_network_deletion boolean)` | postgres | DEFINER | no | yes | no |
| `public.maskan_discover_network(p_network_name text)` | postgres | DEFINER | no | no | no |
| `public.maskan_is_current_member(target_member_id uuid)` | postgres | DEFINER | no | yes | no |
| `public.maskan_is_network_member(target_network_id uuid)` | postgres | DEFINER | no | yes | no |
| `public.maskan_join_network(p_network_id uuid, p_network_name text, p_network_password text, p_member_id uuid, p_member_name text, p_member_password_hash text, p_member_password_salt text)` | postgres | DEFINER | no | no | no |
| `public.maskan_leave_network(p_network_id uuid)` | postgres | DEFINER | no | yes | no |
| `public.maskan_password_create_network(p_auth_user_id uuid, p_network_id uuid, p_member_id uuid, p_network_name text, p_member_name text, p_network_password_digest text, p_member_password_digest text, p_currency_code text, p_currency_symbol text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_find_auth_user(p_email text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_issue_claim(p_member_id uuid, p_auth_user_id uuid, p_token_hash text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_join_network(p_auth_user_id uuid, p_network_id uuid, p_member_id uuid, p_member_name text, p_member_password_digest text, p_verified_network_digest text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_lookup_member(p_network_name text, p_member_name text, p_member_id uuid)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_lookup_network(p_network_id uuid, p_network_name text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_mark_auth_synced(p_member_id uuid, p_credential_version smallint)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_rate_limit_check(p_key_hash text, p_scope text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_rate_limit_cleanup()` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_rate_limit_failure(p_key_hash text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_rate_limit_success(p_key_hash text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_reset_context(p_caller_auth_user_id uuid, p_network_id uuid, p_admin_member_id uuid, p_target_member_id uuid)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_reset_member(p_caller_auth_user_id uuid, p_network_id uuid, p_admin_member_id uuid, p_target_member_id uuid, p_modern_digest text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_upgrade_member(p_member_id uuid, p_expected_legacy_hash text, p_modern_digest text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_password_upgrade_network(p_network_id uuid, p_expected_legacy_hash text, p_modern_digest text)` | postgres | DEFINER | no | no | yes |
| `public.maskan_request_expense_reset(p_network_id uuid, p_cycle_id uuid)` | postgres | DEFINER | no | yes | no |
| `public.maskan_verify_member_credentials(p_network_id uuid, p_member_id uuid, p_member_name text, p_member_password text)` | postgres | DEFINER | no | no | no |
| `public.phase5_cycle_member_belongs_to_network(target_network_id uuid, requester_member_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_expense_members_match_network(target_network_id uuid, paid_member_id uuid, added_member_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_member_belongs_to_network(member_id uuid, target_network_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_network_can_be_deleted_after_leave(target_network_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_network_exists(target_network_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_network_has_no_active_expenses(target_network_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_notification_matches_network(target_network_id uuid, recipient_member_id uuid, actor_member_id uuid, target_expense_id uuid, target_reset_request_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_prevent_notification_identity_update()` | postgres | INVOKER | no | no | no |
| `public.phase5_reset_approval_matches_network(target_network_id uuid, target_reset_request_id uuid, approving_member_id uuid)` | postgres | DEFINER | no | no | no |
| `public.phase5_reset_member_password(target_network_id uuid, admin_member_id uuid, target_member_id uuid, new_password_hash text, new_password_salt text)` | postgres | DEFINER | no | no | no |
| `public.phase5_reset_request_matches_network(target_network_id uuid, target_cycle_id uuid, requester_member_id uuid)` | postgres | DEFINER | no | no | no |
