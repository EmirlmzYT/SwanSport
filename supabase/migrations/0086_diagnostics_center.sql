-- First-party diagnostics: opt-in client, authenticated ingestion, admin-only inspection.
-- Client data is untrusted. Reconstruct allowlisted metadata; never store raw payloads.
set local lock_timeout = '15s';

create table if not exists public.diagnostic_catalog (
  category text not null check (category in ('route','operation','source')),
  value text not null, primary key(category,value)
);
alter table public.diagnostic_catalog enable row level security;
revoke all on public.diagnostic_catalog from public, anon, authenticated;
-- CATALOG START
insert into public.diagnostic_catalog(category, value) values
('route', '/'),
('route', '/admin-user-detail'),
('route', '/aidatlarim'),
('route', '/akis'),
('route', '/announcements'),
('route', '/antrenman-olustur'),
('route', '/antrenman-oturumu'),
('route', '/antrenman-sablonlari'),
('route', '/antrenman-sonuc'),
('route', '/antrenmanlarim'),
('route', '/antrenor-bul'),
('route', '/ara'),
('route', '/athlete-detail'),
('route', '/athletes'),
('route', '/attendance'),
('route', '/auth'),
('route', '/bagis'),
('route', '/baglantilar'),
('route', '/basvurular'),
('route', '/bayraklar'),
('route', '/beslenme'),
('route', '/bildirimler'),
('route', '/butce'),
('route', '/calendar'),
('route', '/communication-detail'),
('route', '/configuration'),
('route', '/configuration-module'),
('route', '/dashboard'),
('route', '/defter'),
('route', '/demo-rol'),
('route', '/destek'),
('route', '/devam-durumu'),
('route', '/document-detail'),
('route', '/documents'),
('route', '/dogrulama'),
('route', '/donem-kapanis'),
('route', '/ekipman-tuning'),
('route', '/etkinlik-detay'),
('route', '/facilities'),
('route', '/federasyon'),
('route', '/federasyon-yetkili'),
('route', '/finans'),
('route', '/gelisim-raporu'),
('route', '/gider-ekle'),
('route', '/gizlilik'),
('route', '/haber-kaynaklari'),
('route', '/halisahalar'),
('route', '/hata-merkezi'),
('route', '/hazirbulunusluk'),
('route', '/home-command'),
('route', '/ilan-ver'),
('route', '/ilanlar'),
('route', '/kasa'),
('route', '/kaydedilenler'),
('route', '/kesfet'),
('route', '/kortlar'),
('route', '/kullanicilar'),
('route', '/kulup-detay'),
('route', '/kulup-profil'),
('route', '/kulupler'),
('route', '/landing'),
('route', '/liderlik'),
('route', '/magaza-basvuru'),
('route', '/mali-isler'),
('route', '/mali-rapor'),
('route', '/medical-center'),
('route', '/mesajlar'),
('route', '/metrikler'),
('route', '/moderasyon'),
('route', '/muhasebeci-defter'),
('route', '/musabaka-simulasyonu'),
('route', '/mutabakat'),
('route', '/onay-paneli'),
('route', '/onaylar'),
('route', '/organizasyonlar'),
('route', '/oyuncu-aranan'),
('route', '/partner-ara'),
('route', '/pazaryeri'),
('route', '/performance-'),
('route', '/performance-analytics'),
('route', '/performance-development-plan'),
('route', '/performance-development-plan-editor'),
('route', '/performance-match-detail'),
('route', '/performance-position-detail'),
('route', '/performance-review-session'),
('route', '/performance-review-session-editor'),
('route', '/performance-self-assessment-editor'),
('route', '/performance-team-detail'),
('route', '/performance-test-session'),
('route', '/performance-test-session-editor'),
('route', '/performance-training-detail'),
('route', '/profil'),
('route', '/report-detail'),
('route', '/reports'),
('route', '/rezervasyon'),
('route', '/saha-islemlerim'),
('route', '/sepet'),
('route', '/settings'),
('route', '/sezon-acilisi'),
('route', '/sohbet'),
('route', '/sporcu-performans'),
('route', '/sporcular'),
('route', '/taahhutler'),
('route', '/tahsilat'),
('route', '/takim-kadro'),
('route', '/takvim'),
('route', '/teams'),
('route', '/ters-islem'),
('route', '/tesisler'),
('route', '/topluluk'),
('route', '/topluluklar'),
('route', '/unknown'),
('route', '/urun'),
('route', '/uygunluk'),
('route', '/veli-bagla'),
('route', '/veli-izinleri'),
('route', '/yardim'),
('route', '/yardim-icerigi'),
('route', '/yaris-detay'),
('route', '/yoklama'),
('operation', 'action:consistency'),
('operation', 'action:facility_reservation'),
('operation', 'action:finance_adjustment'),
('operation', 'action:push_open'),
('operation', 'action:support_ticket'),
('operation', 'async'),
('operation', 'auth'),
('operation', 'framework'),
('operation', 'navigation'),
('operation', 'provider'),
('operation', 'rpc:_advance_court_waitlist'),
('operation', 'rpc:_court_waiter_eligible'),
('operation', 'rpc:_swan_feature_for_profile'),
('operation', 'rpc:acc_account_balances'),
('operation', 'rpc:acc_category_breakdown'),
('operation', 'rpc:acc_closed_period_candidates'),
('operation', 'rpc:acc_ledger'),
('operation', 'rpc:acc_ledger_totals'),
('operation', 'rpc:acc_monthly_summary'),
('operation', 'rpc:acc_operations_summary'),
('operation', 'rpc:acc_receivables'),
('operation', 'rpc:accept_court_waitlist'),
('operation', 'rpc:add_document'),
('operation', 'rpc:add_extra_charge'),
('operation', 'rpc:admin_diagnostic_detail'),
('operation', 'rpc:admin_diagnostic_overview'),
('operation', 'rpc:admin_recent_reviews'),
('operation', 'rpc:admin_search_people'),
('operation', 'rpc:advance_session_phase'),
('operation', 'rpc:apply_test_to_goals'),
('operation', 'rpc:apply_to_club'),
('operation', 'rpc:apply_to_listing'),
('operation', 'rpc:approve_club'),
('operation', 'rpc:approve_finance_adjustment'),
('operation', 'rpc:assign_session_lane'),
('operation', 'rpc:athlete_card'),
('operation', 'rpc:athlete_development_report'),
('operation', 'rpc:athlete_needs_guardian'),
('operation', 'rpc:athlete_ref'),
('operation', 'rpc:attendance_audit'),
('operation', 'rpc:attendance_summary'),
('operation', 'rpc:attendance_version_guard'),
('operation', 'rpc:audit_turf_write'),
('operation', 'rpc:award_attendance_achievements'),
('operation', 'rpc:award_goal_achievement'),
('operation', 'rpc:bank_match_suggestions'),
('operation', 'rpc:bank_transactions_page'),
('operation', 'rpc:block_closed_period'),
('operation', 'rpc:budget_vs_actual'),
('operation', 'rpc:campaign_donors'),
('operation', 'rpc:campaigns'),
('operation', 'rpc:can_edit_turf_occupancy'),
('operation', 'rpc:can_join_community'),
('operation', 'rpc:can_manage_athlete'),
('operation', 'rpc:can_manage_training_session'),
('operation', 'rpc:can_mention'),
('operation', 'rpc:can_post_for_club'),
('operation', 'rpc:can_post_personally'),
('operation', 'rpc:can_read_athlete_vault_file'),
('operation', 'rpc:can_review_club_applications'),
('operation', 'rpc:can_sell_new'),
('operation', 'rpc:can_view_athlete_fees'),
('operation', 'rpc:can_view_athlete_performance'),
('operation', 'rpc:can_view_document'),
('operation', 'rpc:can_view_post'),
('operation', 'rpc:can_view_training_session'),
('operation', 'rpc:cancel_partner_request'),
('operation', 'rpc:cancel_recurring_expense'),
('operation', 'rpc:cancel_slot'),
('operation', 'rpc:cash_forecast'),
('operation', 'rpc:check_event_club_integrity'),
('operation', 'rpc:check_in_slot'),
('operation', 'rpc:check_post_media_limit'),
('operation', 'rpc:check_post_mention_limit'),
('operation', 'rpc:claim_slot'),
('operation', 'rpc:clear_health_restriction'),
('operation', 'rpc:close_finance_period'),
('operation', 'rpc:close_listing'),
('operation', 'rpc:club_achievement_list'),
('operation', 'rpc:club_coaches'),
('operation', 'rpc:club_details'),
('operation', 'rpc:club_eligibility_board'),
('operation', 'rpc:club_fee_ledger'),
('operation', 'rpc:club_filter_options'),
('operation', 'rpc:club_finance_summary'),
('operation', 'rpc:club_members_without_athlete'),
('operation', 'rpc:club_operational_risk'),
('operation', 'rpc:club_operations_summary'),
('operation', 'rpc:club_unlinked_athletes'),
('operation', 'rpc:community_messages_page'),
('operation', 'rpc:complete_draft_expense'),
('operation', 'rpc:confirm_donation'),
('operation', 'rpc:confirm_payment'),
('operation', 'rpc:correct_locked_set'),
('operation', 'rpc:court_checkin_radius'),
('operation', 'rpc:court_slot_maintenance'),
('operation', 'rpc:court_sport_codes'),
('operation', 'rpc:court_timeline'),
('operation', 'rpc:court_usage_by_court'),
('operation', 'rpc:court_usage_stats'),
('operation', 'rpc:court_waitlist_claim_guard'),
('operation', 'rpc:court_waitlist_lock'),
('operation', 'rpc:court_waitlist_maintenance'),
('operation', 'rpc:court_waitlist_slot_changed'),
('operation', 'rpc:court_waitlist_transition_guard'),
('operation', 'rpc:create_accountant_invite'),
('operation', 'rpc:create_athlete_from_member'),
('operation', 'rpc:create_club'),
('operation', 'rpc:create_draft_expense'),
('operation', 'rpc:create_event'),
('operation', 'rpc:create_event_series'),
('operation', 'rpc:create_finance_adjustment'),
('operation', 'rpc:create_guardian_invite'),
('operation', 'rpc:create_listing'),
('operation', 'rpc:create_market_listing'),
('operation', 'rpc:create_organization'),
('operation', 'rpc:create_repost_or_quote'),
('operation', 'rpc:create_training_protocol'),
('operation', 'rpc:create_turf_duty'),
('operation', 'rpc:create_turf_manager_invite'),
('operation', 'rpc:credentials_without_sport'),
('operation', 'rpc:decide_bank_match'),
('operation', 'rpc:decide_expense_approval'),
('operation', 'rpc:declare_diagnostic_fix'),
('operation', 'rpc:declare_payment'),
('operation', 'rpc:default_post_visibility'),
('operation', 'rpc:delete_event_series'),
('operation', 'rpc:delete_my_account'),
('operation', 'rpc:development_report_athletes'),
('operation', 'rpc:diagnostic_release_parts'),
('operation', 'rpc:discover_clubs'),
('operation', 'rpc:document_list'),
('operation', 'rpc:donate'),
('operation', 'rpc:drop_push_subscription'),
('operation', 'rpc:eligibility_gate'),
('operation', 'rpc:eligible_supervisors'),
('operation', 'rpc:end_membership'),
('operation', 'rpc:enforce_coach_hierarchy'),
('operation', 'rpc:ensure_individual_athlete'),
('operation', 'rpc:ensure_my_communities'),
('operation', 'rpc:ensure_my_team_channels'),
('operation', 'rpc:ensure_team_channel'),
('operation', 'rpc:event_audience'),
('operation', 'rpc:event_roster'),
('operation', 'rpc:event_roster_versioned'),
('operation', 'rpc:event_rsvp_summary'),
('operation', 'rpc:expense_audit_trail'),
('operation', 'rpc:expense_policy_for'),
('operation', 'rpc:extend_slot'),
('operation', 'rpc:facility_conflicts'),
('operation', 'rpc:facility_load'),
('operation', 'rpc:facility_schedule'),
('operation', 'rpc:faq_coverage'),
('operation', 'rpc:federation_announcements'),
('operation', 'rpc:finance_adjustment_entry_matches'),
('operation', 'rpc:generate_fee_charges'),
('operation', 'rpc:generate_fixture'),
('operation', 'rpc:generate_join_code'),
('operation', 'rpc:generate_recurring_occurrences'),
('operation', 'rpc:get_finance_adjustment_reconciliation_issues'),
('operation', 'rpc:goal_progress'),
('operation', 'rpc:guard_delegated_turf_write'),
('operation', 'rpc:guard_listing_image_count'),
('operation', 'rpc:guard_store_status'),
('operation', 'rpc:guard_training_protocol_immutable'),
('operation', 'rpc:guard_vault_file_association'),
('operation', 'rpc:handle_new_user'),
('operation', 'rpc:has_approved_credential'),
('operation', 'rpc:hidden_profiles'),
('operation', 'rpc:import_bank_statement'),
('operation', 'rpc:ingest_diagnostics'),
('operation', 'rpc:is_athlete_self'),
('operation', 'rpc:is_authorized_health_officer'),
('operation', 'rpc:is_blocked_between'),
('operation', 'rpc:is_club_accountant'),
('operation', 'rpc:is_club_admin'),
('operation', 'rpc:is_club_member'),
('operation', 'rpc:is_club_staff'),
('operation', 'rpc:is_community_member'),
('operation', 'rpc:is_community_staff'),
('operation', 'rpc:is_guardian_of'),
('operation', 'rpc:is_minor_profile'),
('operation', 'rpc:is_org_owner'),
('operation', 'rpc:is_period_closed'),
('operation', 'rpc:is_platform_admin'),
('operation', 'rpc:is_store_manager'),
('operation', 'rpc:is_turf_manager'),
('operation', 'rpc:is_verified_coach'),
('operation', 'rpc:join_community'),
('operation', 'rpc:join_court_waitlist'),
('operation', 'rpc:join_organization'),
('operation', 'rpc:join_training_session'),
('operation', 'rpc:leave_community'),
('operation', 'rpc:leave_court_waitlist'),
('operation', 'rpc:link_athlete_to_member'),
('operation', 'rpc:link_support_issue'),
('operation', 'rpc:list_organizations'),
('operation', 'rpc:listing_applicants'),
('operation', 'rpc:lock_session_results'),
('operation', 'rpc:log_athlete_water'),
('operation', 'rpc:log_attendance_change'),
('operation', 'rpc:log_expense_change'),
('operation', 'rpc:mark_community_read'),
('operation', 'rpc:mark_conversation_read'),
('operation', 'rpc:mark_messages_read'),
('operation', 'rpc:mask_bank_text'),
('operation', 'rpc:message_replies'),
('operation', 'rpc:meters_between'),
('operation', 'rpc:my_children_overview'),
('operation', 'rpc:my_coach_sports'),
('operation', 'rpc:my_communities'),
('operation', 'rpc:my_conversations'),
('operation', 'rpc:my_court_waitlist'),
('operation', 'rpc:my_delegated_turf_fields'),
('operation', 'rpc:my_event_rsvp'),
('operation', 'rpc:my_feature_flags'),
('operation', 'rpc:my_fees'),
('operation', 'rpc:my_incoming_partner_pings'),
('operation', 'rpc:my_listings'),
('operation', 'rpc:my_live_training_session'),
('operation', 'rpc:my_notification_prefs'),
('operation', 'rpc:my_notifications'),
('operation', 'rpc:my_open_partner_request'),
('operation', 'rpc:my_parent_actions'),
('operation', 'rpc:my_saved_posts'),
('operation', 'rpc:my_training_history'),
('operation', 'rpc:my_turf_duties'),
('operation', 'rpc:normalize_city'),
('operation', 'rpc:notification_category'),
('operation', 'rpc:notify_direct_message'),
('operation', 'rpc:notify_federation_message'),
('operation', 'rpc:notify_moderation'),
('operation', 'rpc:notify_new_achievement'),
('operation', 'rpc:notify_new_announcement'),
('operation', 'rpc:notify_new_event'),
('operation', 'rpc:notify_store_decision'),
('operation', 'rpc:notify_training_results_locked'),
('operation', 'rpc:notify_training_session_started'),
('operation', 'rpc:observe_diagnostic_fix'),
('operation', 'rpc:offer_to_person'),
('operation', 'rpc:open_club_season'),
('operation', 'rpc:open_health_restriction'),
('operation', 'rpc:open_slots'),
('operation', 'rpc:open_support_ticket'),
('operation', 'rpc:org_fixture'),
('operation', 'rpc:org_standings'),
('operation', 'rpc:partner_request_maintenance'),
('operation', 'rpc:pending_achievements'),
('operation', 'rpc:pending_payments'),
('operation', 'rpc:performance_overview'),
('operation', 'rpc:period_close_checklist'),
('operation', 'rpc:person_club_history'),
('operation', 'rpc:person_summary'),
('operation', 'rpc:platform_stats'),
('operation', 'rpc:post_share_to_dm'),
('operation', 'rpc:prepare_attendance_offline'),
('operation', 'rpc:public_events'),
('operation', 'rpc:purge_diagnostics'),
('operation', 'rpc:purge_expired_records'),
('operation', 'rpc:push_allowed'),
('operation', 'rpc:push_notification'),
('operation', 'rpc:push_on_notification'),
('operation', 'rpc:push_route'),
('operation', 'rpc:push_secret'),
('operation', 'rpc:push_subscription_state'),
('operation', 'rpc:record_payment'),
('operation', 'rpc:record_recurring_occurrence'),
('operation', 'rpc:redeem_invite_code'),
('operation', 'rpc:redeem_turf_duty'),
('operation', 'rpc:register_for_event'),
('operation', 'rpc:register_push_subscription'),
('operation', 'rpc:reject_club'),
('operation', 'rpc:reopen_finance_period'),
('operation', 'rpc:reply_support_ticket'),
('operation', 'rpc:request_join'),
('operation', 'rpc:request_turf_slot'),
('operation', 'rpc:require_faq_before_release'),
('operation', 'rpc:respond_partner_ping'),
('operation', 'rpc:respond_support_fix'),
('operation', 'rpc:review_club_application'),
('operation', 'rpc:review_credential'),
('operation', 'rpc:review_join'),
('operation', 'rpc:review_listing_application'),
('operation', 'rpc:review_participant'),
('operation', 'rpc:review_report'),
('operation', 'rpc:revise_training_protocol'),
('operation', 'rpc:revoke_turf_duty'),
('operation', 'rpc:sanitize_support_text'),
('operation', 'rpc:save_attendance_offline'),
('operation', 'rpc:save_attendance_ops'),
('operation', 'rpc:scan_roster_eligibility'),
('operation', 'rpc:search_coaches'),
('operation', 'rpc:search_faq'),
('operation', 'rpc:search_hashtags'),
('operation', 'rpc:search_listings'),
('operation', 'rpc:search_market_listings'),
('operation', 'rpc:search_mentionable'),
('operation', 'rpc:seek_partner'),
('operation', 'rpc:send_approval_reminders'),
('operation', 'rpc:send_attendance_reminders'),
('operation', 'rpc:send_club_message'),
('operation', 'rpc:send_commitment_reminders'),
('operation', 'rpc:send_document_expiry_reminders'),
('operation', 'rpc:send_fee_reminders'),
('operation', 'rpc:send_finance_alerts'),
('operation', 'rpc:session_attendance_hint'),
('operation', 'rpc:session_overview'),
('operation', 'rpc:session_summary'),
('operation', 'rpc:set_athlete_nutrition_targets'),
('operation', 'rpc:set_club_media'),
('operation', 'rpc:set_coach_discoverable'),
('operation', 'rpc:set_community_staff'),
('operation', 'rpc:set_credential_sport'),
('operation', 'rpc:set_diagnostic_issue_status'),
('operation', 'rpc:set_event_rsvp'),
('operation', 'rpc:set_guardian_event_rsvp'),
('operation', 'rpc:set_health_officer'),
('operation', 'rpc:set_market_listing_status'),
('operation', 'rpc:set_match_result'),
('operation', 'rpc:set_notification_pref'),
('operation', 'rpc:set_pinned_post'),
('operation', 'rpc:set_platform_admin'),
('operation', 'rpc:set_post_tags'),
('operation', 'rpc:set_social_privacy'),
('operation', 'rpc:set_support_status'),
('operation', 'rpc:set_training_pause'),
('operation', 'rpc:set_updated_at'),
('operation', 'rpc:shared_content_card'),
('operation', 'rpc:split_full_name'),
('operation', 'rpc:start_personal_session'),
('operation', 'rpc:start_training_session'),
('operation', 'rpc:submit_expense_for_approval'),
('operation', 'rpc:submit_set_score'),
('operation', 'rpc:support_fix_context'),
('operation', 'rpc:support_queue'),
('operation', 'rpc:sync_post_like_count'),
('operation', 'rpc:sync_team_channel_name'),
('operation', 'rpc:toggle_saved_post'),
('operation', 'rpc:tr_contains'),
('operation', 'rpc:tr_fold'),
('operation', 'rpc:training_next_phase'),
('operation', 'rpc:training_phase_seconds'),
('operation', 'rpc:trg_block_cleanup'),
('operation', 'rpc:trg_notify_application'),
('operation', 'rpc:trg_notify_application_review'),
('operation', 'rpc:trg_notify_comment'),
('operation', 'rpc:trg_notify_credential_review'),
('operation', 'rpc:trg_notify_follow'),
('operation', 'rpc:trg_notify_like'),
('operation', 'rpc:turf_occupancy_grid'),
('operation', 'rpc:unlink_support_issue'),
('operation', 'rpc:update_athlete_sport_info'),
('operation', 'rpc:update_club_details'),
('operation', 'rpc:update_club_profile'),
('operation', 'rpc:update_coach_profile'),
('operation', 'rpc:valid_training_config'),
('operation', 'rpc:verification_rank'),
('operation', 'rpc:verify_athlete_achievement'),
('operation', 'rpc:verify_court_location'),
('operation', 'rpc:verify_document'),
('operation', 'storage'),
('operation', 'table:announcements'),
('operation', 'table:athlete_achievements'),
('operation', 'table:athlete_equipment'),
('operation', 'table:athlete_fees'),
('operation', 'table:athlete_nutrition_logs'),
('operation', 'table:athlete_nutrition_targets'),
('operation', 'table:athletes'),
('operation', 'table:attendance'),
('operation', 'table:attendance_audit_log'),
('operation', 'table:attendance_op_logs'),
('operation', 'table:bank_imports'),
('operation', 'table:bank_reconcile_logs'),
('operation', 'table:bank_transactions'),
('operation', 'table:blocks'),
('operation', 'table:budgets'),
('operation', 'table:cash_accounts'),
('operation', 'table:cities'),
('operation', 'table:club_accountants'),
('operation', 'table:club_achievements'),
('operation', 'table:club_applications'),
('operation', 'table:club_memberships'),
('operation', 'table:club_staff_permissions'),
('operation', 'table:clubs'),
('operation', 'table:communities'),
('operation', 'table:community_members'),
('operation', 'table:community_messages'),
('operation', 'table:content_reports'),
('operation', 'table:court_players'),
('operation', 'table:court_slot_players'),
('operation', 'table:court_slots'),
('operation', 'table:court_waitlist'),
('operation', 'table:courts'),
('operation', 'table:development_goals'),
('operation', 'table:diagnostic_fixes'),
('operation', 'table:direct_messages'),
('operation', 'table:documents'),
('operation', 'table:donation_campaigns'),
('operation', 'table:donations'),
('operation', 'table:event_registrations'),
('operation', 'table:event_rsvps'),
('operation', 'table:events'),
('operation', 'table:expense_approval_policies'),
('operation', 'table:expense_approvals'),
('operation', 'table:expense_audit_logs'),
('operation', 'table:expense_categories'),
('operation', 'table:expenses'),
('operation', 'table:facilities'),
('operation', 'table:faq_entries'),
('operation', 'table:feature_flag_testers'),
('operation', 'table:feature_flags'),
('operation', 'table:fee_plans'),
('operation', 'table:finance_adjustments'),
('operation', 'table:finance_period_logs'),
('operation', 'table:finance_periods'),
('operation', 'table:follows'),
('operation', 'table:guardians'),
('operation', 'table:health_restrictions'),
('operation', 'table:import_batches'),
('operation', 'table:injuries'),
('operation', 'table:invite_codes'),
('operation', 'table:invoices'),
('operation', 'table:listing_applications'),
('operation', 'table:listing_images'),
('operation', 'table:listings'),
('operation', 'table:marketplace_favorites'),
('operation', 'table:marketplace_reports'),
('operation', 'table:notification_preferences'),
('operation', 'table:notification_prefs'),
('operation', 'table:notifications'),
('operation', 'table:org_matches'),
('operation', 'table:org_participants'),
('operation', 'table:organizations'),
('operation', 'table:partner_request_pings'),
('operation', 'table:partner_requests'),
('operation', 'table:payments'),
('operation', 'table:performance_tests'),
('operation', 'table:post_comments'),
('operation', 'table:post_hashtags'),
('operation', 'table:post_likes'),
('operation', 'table:post_media'),
('operation', 'table:post_mentions'),
('operation', 'table:posts'),
('operation', 'table:profile_credentials'),
('operation', 'table:profiles'),
('operation', 'table:push_subscriptions'),
('operation', 'table:recurring_expenses'),
('operation', 'table:recurring_occurrences'),
('operation', 'table:reminder_log'),
('operation', 'table:rss_sources'),
('operation', 'table:saved_posts'),
('operation', 'table:season_setup_runs'),
('operation', 'table:seasons'),
('operation', 'table:sport_interests'),
('operation', 'table:sports'),
('operation', 'table:store_memberships'),
('operation', 'table:stores'),
('operation', 'table:support_messages'),
('operation', 'table:support_tickets'),
('operation', 'table:team_memberships'),
('operation', 'table:teams'),
('operation', 'table:training_protocols'),
('operation', 'table:training_self_assessments'),
('operation', 'table:training_session_events'),
('operation', 'table:training_session_participants'),
('operation', 'table:training_sessions'),
('operation', 'table:training_set_entries'),
('operation', 'table:training_sets'),
('operation', 'table:turf_duty_delegations'),
('operation', 'table:turf_field_managers'),
('operation', 'table:turf_fields'),
('operation', 'table:turf_occupancy'),
('operation', 'table:turf_occupancy_audit'),
('operation', 'table:turf_slot_requests'),
('operation', 'table:vendor_private'),
('operation', 'table:vendors'),
('operation', 'table:verification_documents'),
('operation', 'unknown'),
('source', 'package:swansport_app/app/app_navigator.dart'),
('source', 'package:swansport_app/app/bootstrap/bootstrap.dart'),
('source', 'package:swansport_app/app/bootstrap/startup_failure_app.dart'),
('source', 'package:swansport_app/app/config/app_environment.dart'),
('source', 'package:swansport_app/app/design/swan_brand.dart'),
('source', 'package:swansport_app/app/design/swan_palette.dart'),
('source', 'package:swansport_app/app/design/swan_shape.dart'),
('source', 'package:swansport_app/app/design/swan_type.dart'),
('source', 'package:swansport_app/app/diagnostics/diagnostic_preferences_tile.dart'),
('source', 'package:swansport_app/app/diagnostics/diagnostic_runtime.dart'),
('source', 'package:swansport_app/app/l10n/app_locale.dart'),
('source', 'package:swansport_app/app/l10n/swan_localizations.dart'),
('source', 'package:swansport_app/app/location/place.dart'),
('source', 'package:swansport_app/app/media/image_pick.dart'),
('source', 'package:swansport_app/app/media/image_pick_io.dart'),
('source', 'package:swansport_app/app/media/image_pick_web.dart'),
('source', 'package:swansport_app/app/push/push.dart'),
('source', 'package:swansport_app/app/push/push_io.dart'),
('source', 'package:swansport_app/app/push/push_service.dart'),
('source', 'package:swansport_app/app/push/push_web.dart'),
('source', 'package:swansport_app/app/swansport_app.dart'),
('source', 'package:swansport_app/app/theme/app_theme.dart'),
('source', 'package:swansport_app/app/theme/theme_mode_controller.dart'),
('source', 'package:swansport_app/app/update/update_checker.dart'),
('source', 'package:swansport_app/app/update/update_downloader.dart'),
('source', 'package:swansport_app/app/update/update_gate.dart'),
('source', 'package:swansport_app/app/widgets/create_sheet.dart'),
('source', 'package:swansport_app/app/widgets/identity_header.dart'),
('source', 'package:swansport_app/app/widgets/inbox_actions.dart'),
('source', 'package:swansport_app/app/widgets/page_transitions.dart'),
('source', 'package:swansport_app/app/widgets/pending_work.dart'),
('source', 'package:swansport_app/app/widgets/premium.dart'),
('source', 'package:swansport_app/app/widgets/quick_actions.dart'),
('source', 'package:swansport_app/app/widgets/quick_form.dart'),
('source', 'package:swansport_app/app/widgets/shared_content_card.dart'),
('source', 'package:swansport_app/app/widgets/stitch_components.dart'),
('source', 'package:swansport_app/app/widgets/summary_section.dart'),
('source', 'package:swansport_app/app/widgets/swan_bottom_nav.dart'),
('source', 'package:swansport_app/app/widgets/swan_chip.dart'),
('source', 'package:swansport_app/app/widgets/swan_page_header.dart'),
('source', 'package:swansport_app/app/widgets/swan_skeleton.dart'),
('source', 'package:swansport_app/app/widgets/swan_tabs.dart'),
('source', 'package:swansport_app/app/widgets/tag_composer.dart'),
('source', 'package:swansport_app/app/widgets/today_tasks.dart'),
('source', 'package:swansport_app/app/widgets/unavailable_feature_screen.dart'),
('source', 'package:swansport_app/features/announcements/application/communication_center_controller.dart'),
('source', 'package:swansport_app/features/announcements/application/communication_center_permissions.dart'),
('source', 'package:swansport_app/features/announcements/application/communication_center_state.dart'),
('source', 'package:swansport_app/features/announcements/application/communication_composer_draft.dart'),
('source', 'package:swansport_app/features/announcements/application/communication_detail_controller.dart'),
('source', 'package:swansport_app/features/announcements/application/communication_detail_state.dart'),
('source', 'package:swansport_app/features/announcements/application/communication_operational_link_resolver.dart'),
('source', 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart'),
('source', 'package:swansport_app/features/announcements/data/fixtures/fixture_audience_resolver.dart'),
('source', 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart'),
('source', 'package:swansport_app/features/announcements/domain/models/acknowledge_communication_command.dart'),
('source', 'package:swansport_app/features/announcements/domain/models/audience_resolution.dart'),
('source', 'package:swansport_app/features/announcements/domain/models/communication_center.dart'),
('source', 'package:swansport_app/features/announcements/domain/models/schedule_communication_command.dart'),
('source', 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart'),
('source', 'package:swansport_app/features/announcements/presentation/routing/communication_detail_route_args.dart'),
('source', 'package:swansport_app/features/announcements/presentation/screens/announcements_screen.dart'),
('source', 'package:swansport_app/features/announcements/presentation/screens/communication_detail_screen.dart'),
('source', 'package:swansport_app/features/athlete_workspace/application/athlete_detail_controller.dart'),
('source', 'package:swansport_app/features/athlete_workspace/application/athlete_detail_permissions.dart'),
('source', 'package:swansport_app/features/athlete_workspace/application/athlete_detail_state.dart'),
('source', 'package:swansport_app/features/athlete_workspace/data/fixtures/athlete_detail_fixture_data_source.dart'),
('source', 'package:swansport_app/features/athlete_workspace/data/repositories/fixture_athlete_detail_repository.dart'),
('source', 'package:swansport_app/features/athlete_workspace/domain/models/athlete_detail.dart'),
('source', 'package:swansport_app/features/athlete_workspace/domain/repositories/athlete_detail_repository.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_detail_screen.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_home_screen.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_workspace_screen.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/screens/nutrition_tracker_screen.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/widgets/add_athlete_sheet.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/widgets/athlete_profile_section.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/widgets/getting_started_card.dart'),
('source', 'package:swansport_app/features/athlete_workspace/presentation/widgets/link_athletes_sheet.dart'),
('source', 'package:swansport_app/features/attendance/presentation/attendance_queue_banner.dart'),
('source', 'package:swansport_app/features/attendance/presentation/screens/attendance_history_screen.dart'),
('source', 'package:swansport_app/features/attendance/presentation/screens/attendance_workspace.dart'),
('source', 'package:swansport_app/features/attendance/presentation/screens/live_attendance_screen.dart'),
('source', 'package:swansport_app/features/auth/application/auth_controller.dart'),
('source', 'package:swansport_app/features/auth/presentation/screens/auth_gate.dart'),
('source', 'package:swansport_app/features/auth/presentation/screens/auth_screen.dart'),
('source', 'package:swansport_app/features/calendar/application/schedule_calendar_controller.dart'),
('source', 'package:swansport_app/features/calendar/application/schedule_calendar_permissions.dart'),
('source', 'package:swansport_app/features/calendar/application/schedule_calendar_state.dart'),
('source', 'package:swansport_app/features/calendar/data/fixtures/schedule_calendar_fixture_data_source.dart'),
('source', 'package:swansport_app/features/calendar/data/repositories/fixture_schedule_calendar_repository.dart'),
('source', 'package:swansport_app/features/calendar/domain/models/calendar_workspace.dart'),
('source', 'package:swansport_app/features/calendar/domain/repositories/schedule_calendar_repository.dart'),
('source', 'package:swansport_app/features/calendar/presentation/screens/event_roster_detail_screen.dart'),
('source', 'package:swansport_app/features/calendar/presentation/screens/race_event_detail_screen.dart'),
('source', 'package:swansport_app/features/calendar/presentation/screens/schedule_calendar_screen.dart'),
('source', 'package:swansport_app/features/clubs/presentation/club_applications_screen.dart'),
('source', 'package:swansport_app/features/clubs/presentation/club_apply_button.dart'),
('source', 'package:swansport_app/features/clubs/presentation/club_detail_sections.dart'),
('source', 'package:swansport_app/features/clubs/presentation/club_edit_sheet.dart'),
('source', 'package:swansport_app/features/clubs/presentation/club_profile_detail_screen.dart'),
('source', 'package:swansport_app/features/clubs/presentation/coach_accept_sheet.dart'),
('source', 'package:swansport_app/features/clubs/presentation/invite_to_club_button.dart'),
('source', 'package:swansport_app/features/communities/presentation/community_chat_screen.dart'),
('source', 'package:swansport_app/features/communities/presentation/federation_admin_screen.dart'),
('source', 'package:swansport_app/features/communities/presentation/federation_channel_screen.dart'),
('source', 'package:swansport_app/features/configuration/application/configuration_controller.dart'),
('source', 'package:swansport_app/features/configuration/domain/club_configuration.dart'),
('source', 'package:swansport_app/features/configuration/presentation/configuration_module_args.dart'),
('source', 'package:swansport_app/features/configuration/presentation/configuration_screen.dart'),
('source', 'package:swansport_app/features/configuration/presentation/season_setup_screen.dart'),
('source', 'package:swansport_app/features/courts/presentation/claim_sheet.dart'),
('source', 'package:swansport_app/features/courts/presentation/court_detail_screen.dart'),
('source', 'package:swansport_app/features/courts/presentation/find_partner_screen.dart'),
('source', 'package:swansport_app/features/courts/presentation/join_requests_sheet.dart'),
('source', 'package:swansport_app/features/courts/presentation/venues_screen.dart'),
('source', 'package:swansport_app/features/dashboard/presentation/screens/coach_dashboard_screen.dart'),
('source', 'package:swansport_app/features/demo/demo_role.dart'),
('source', 'package:swansport_app/features/demo/demo_role_screen.dart'),
('source', 'package:swansport_app/features/documents/application/document_detail_controller.dart'),
('source', 'package:swansport_app/features/documents/application/document_permissions.dart'),
('source', 'package:swansport_app/features/documents/application/document_vault_controller.dart'),
('source', 'package:swansport_app/features/documents/data/fixture_document_repository.dart'),
('source', 'package:swansport_app/features/documents/domain/models/document_vault.dart'),
('source', 'package:swansport_app/features/documents/presentation/routing/document_detail_route_args.dart'),
('source', 'package:swansport_app/features/documents/presentation/screens/document_detail_screen.dart'),
('source', 'package:swansport_app/features/documents/presentation/screens/document_vault_screen.dart'),
('source', 'package:swansport_app/features/equipment/presentation/equipment_tuning_screen.dart'),
('source', 'package:swansport_app/features/facilities/application/facility_controller.dart'),
('source', 'package:swansport_app/features/facilities/domain/facility_management.dart'),
('source', 'package:swansport_app/features/facilities/presentation/facility_management_screen.dart'),
('source', 'package:swansport_app/features/facilities/presentation/facility_reservation_screen.dart'),
('source', 'package:swansport_app/features/facilities/presentation/facility_route_args.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/accountant_privacy_ledger_screen.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/campaigns_screen.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/closed_period_reversal_screen.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/fee_plan_status_switch.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/finance_screen.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/finance_tasks_screen.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/my_fees_screen.dart'),
('source', 'package:swansport_app/features/financial_management/presentation/quick_expense_screen.dart'),
('source', 'package:swansport_app/features/home/application/home_controller.dart'),
('source', 'package:swansport_app/features/home/domain/home_command_center.dart'),
('source', 'package:swansport_app/features/home/presentation/screens/guardian_home_screen.dart'),
('source', 'package:swansport_app/features/home/presentation/screens/home_command_center_screen.dart'),
('source', 'package:swansport_app/features/home/presentation/screens/member_home_screen.dart'),
('source', 'package:swansport_app/features/home/presentation/screens/public_landing_screen.dart'),
('source', 'package:swansport_app/features/home/presentation/widgets/role_context_switcher.dart'),
('source', 'package:swansport_app/features/marketplace/presentation/cart_checkout_screen.dart'),
('source', 'package:swansport_app/features/marketplace/presentation/create_listing_screen.dart'),
('source', 'package:swansport_app/features/marketplace/presentation/listing_detail_screen.dart'),
('source', 'package:swansport_app/features/marketplace/presentation/marketplace_screen.dart'),
('source', 'package:swansport_app/features/marketplace/presentation/store_application_screen.dart'),
('source', 'package:swansport_app/features/medical_center/application/medical_controller.dart'),
('source', 'package:swansport_app/features/medical_center/domain/medical_center.dart'),
('source', 'package:swansport_app/features/medical_center/presentation/medical_center_screen.dart'),
('source', 'package:swansport_app/features/medical_center/presentation/medical_route_args.dart'),
('source', 'package:swansport_app/features/network/presentation/coach_discovery_screen.dart'),
('source', 'package:swansport_app/features/network/presentation/discover_screen.dart'),
('source', 'package:swansport_app/features/network/presentation/equipment_listing_sheet.dart'),
('source', 'package:swansport_app/features/network/presentation/explore_screen.dart'),
('source', 'package:swansport_app/features/network/presentation/listings_screen.dart'),
('source', 'package:swansport_app/features/network/presentation/organizations_screen.dart'),
('source', 'package:swansport_app/features/network/presentation/swan_card_sheet.dart'),
('source', 'package:swansport_app/features/onboarding/presentation/onboarding_screen.dart'),
('source', 'package:swansport_app/features/performance_analytics/application/performance_controller.dart'),
('source', 'package:swansport_app/features/performance_analytics/domain/performance_analytics.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/athlete_performance_screen.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/leaderboard_screen.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/performance_analytics_screen.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/performance_route_args.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/performance_workflow_editors.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/performance_workflow_screens.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/readiness_rpe_screen.dart'),
('source', 'package:swansport_app/features/performance_analytics/presentation/test_categories.dart'),
('source', 'package:swansport_app/features/reports/application/reports_controller.dart'),
('source', 'package:swansport_app/features/reports/domain/reports_models.dart'),
('source', 'package:swansport_app/features/reports/presentation/routing/report_detail_args.dart'),
('source', 'package:swansport_app/features/reports/presentation/screens/development_report_screen.dart'),
('source', 'package:swansport_app/features/reports/presentation/screens/report_detail_screen.dart'),
('source', 'package:swansport_app/features/reports/presentation/screens/reports_screen.dart'),
('source', 'package:swansport_app/features/reports/presentation/widgets/development_report_export.dart'),
('source', 'package:swansport_app/features/saha_operations/presentation/saha_operations_screen.dart'),
('source', 'package:swansport_app/features/saha_operations/presentation/turf_duty_invite_dialog.dart'),
('source', 'package:swansport_app/features/settings/application/administration_controller.dart'),
('source', 'package:swansport_app/features/settings/domain/administration.dart'),
('source', 'package:swansport_app/features/settings/presentation/routing/admin_user_detail_args.dart'),
('source', 'package:swansport_app/features/settings/presentation/screens/admin_user_detail_screen.dart'),
('source', 'package:swansport_app/features/settings/presentation/screens/club_settings_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/comments_sheet.dart'),
('source', 'package:swansport_app/features/social/presentation/connections_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/edit_profile_sheet.dart'),
('source', 'package:swansport_app/features/social/presentation/feed_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/messages_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/notifications_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/post_composer_sheet.dart'),
('source', 'package:swansport_app/features/social/presentation/privacy_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/profile_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/rss_admin_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/saved_posts_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/search_screen.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/feed_entry.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/follow_suggestions.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/management_section.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/post_card.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/profile_sections.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/report_sheet.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/social_widgets.dart'),
('source', 'package:swansport_app/features/social/presentation/widgets/stitch_feed_widgets.dart'),
('source', 'package:swansport_app/features/support/presentation/help_screen.dart'),
('source', 'package:swansport_app/features/support/presentation/report_problem_sheet.dart'),
('source', 'package:swansport_app/features/support/presentation/support_fix_card.dart'),
('source', 'package:swansport_app/features/support/presentation/support_screen.dart'),
('source', 'package:swansport_app/features/teams/presentation/screens/team_roster_directory_screen.dart'),
('source', 'package:swansport_app/features/teams/presentation/screens/team_roster_screen.dart'),
('source', 'package:swansport_app/features/training/presentation/match_simulation_screen.dart'),
('source', 'package:swansport_app/features/training/presentation/my_training_screen.dart'),
('source', 'package:swansport_app/features/training/presentation/protocol_list_screen.dart'),
('source', 'package:swansport_app/features/training/presentation/session_result_screen.dart'),
('source', 'package:swansport_app/features/training/presentation/session_screen.dart'),
('source', 'package:swansport_app/features/training/presentation/widgets/archery_target.dart'),
('source', 'package:swansport_app/features/training/presentation/widgets/phase_timer.dart'),
('source', 'package:swansport_app/features/training/presentation/widgets/score_pad.dart'),
('source', 'package:swansport_app/features/training/presentation/workout_builder_screen.dart'),
('source', 'package:swansport_app/features/turf/presentation/turf_field_detail_screen.dart'),
('source', 'package:swansport_app/features/verification/presentation/admin_review_screen.dart'),
('source', 'package:swansport_app/features/verification/presentation/admin_review_widgets.dart'),
('source', 'package:swansport_app/features/verification/presentation/club_pending_screen.dart'),
('source', 'package:swansport_app/features/verification/presentation/credential_screen.dart'),
('source', 'package:swansport_app/features/verification/presentation/guardian_link_screen.dart'),
('source', 'package:swansport_app/features/verification/presentation/parent_consent_center_screen.dart'),
('source', 'package:swansport_app/features/verification/presentation/role_select_screen.dart'),
('source', 'package:swansport_app/main.dart'),
('source', 'package:swansport_app/main_development.dart'),
('source', 'package:swansport_app/main_production.dart'),
('source', 'package:swansport_console/app/console_app.dart'),
('source', 'package:swansport_console/app/console_bootstrap.dart'),
('source', 'package:swansport_console/app/console_router.dart'),
('source', 'package:swansport_console/app/modules/console_module.dart'),
('source', 'package:swansport_console/app/modules/module_registry.dart'),
('source', 'package:swansport_console/app/shell/console_shell.dart'),
('source', 'package:swansport_console/app/shell/too_narrow_notice.dart'),
('source', 'package:swansport_console/app/theme/console_theme.dart'),
('source', 'package:swansport_console/app/widgets/console_table.dart'),
('source', 'package:swansport_console/app/widgets/csv_download_stub.dart'),
('source', 'package:swansport_console/app/widgets/csv_download_web.dart'),
('source', 'package:swansport_console/app/widgets/csv_export.dart'),
('source', 'package:swansport_console/app/widgets/status_pill.dart'),
('source', 'package:swansport_console/features/athletes/athlete_detail_screen.dart'),
('source', 'package:swansport_console/features/athletes/athletes_providers.dart'),
('source', 'package:swansport_console/features/athletes/athletes_screen.dart'),
('source', 'package:swansport_console/features/athletes/eligibility_screen.dart'),
('source', 'package:swansport_console/features/auth/console_login_screen.dart'),
('source', 'package:swansport_console/features/finance/accountants_dialog.dart'),
('source', 'package:swansport_console/features/finance/accounts_screen.dart'),
('source', 'package:swansport_console/features/finance/budget_screen.dart'),
('source', 'package:swansport_console/features/finance/collections_screen.dart'),
('source', 'package:swansport_console/features/finance/commitments_screen.dart'),
('source', 'package:swansport_console/features/finance/expense_dialog.dart'),
('source', 'package:swansport_console/features/finance/finance_charts.dart'),
('source', 'package:swansport_console/features/finance/ledger_providers.dart'),
('source', 'package:swansport_console/features/finance/ledger_screen.dart'),
('source', 'package:swansport_console/features/finance/operations_screen.dart'),
('source', 'package:swansport_console/features/finance/period_close_screen.dart'),
('source', 'package:swansport_console/features/finance/reconciliation_screen.dart'),
('source', 'package:swansport_console/features/finance/report_screen.dart'),
('source', 'package:swansport_console/features/finance/work_queue.dart'),
('source', 'package:swansport_console/features/platform/approvals_screen.dart'),
('source', 'package:swansport_console/features/platform/courts_screen.dart'),
('source', 'package:swansport_console/features/platform/diagnostic_fix_dialog.dart'),
('source', 'package:swansport_console/features/platform/diagnostics_screen.dart'),
('source', 'package:swansport_console/features/platform/faq_screen.dart'),
('source', 'package:swansport_console/features/platform/feature_flags_screen.dart'),
('source', 'package:swansport_console/features/platform/marketplace_admin_screen.dart'),
('source', 'package:swansport_console/features/platform/platform_screens.dart'),
('source', 'package:swansport_console/features/platform/support_diagnostic_panel.dart'),
('source', 'package:swansport_console/features/platform/support_fix_panel.dart'),
('source', 'package:swansport_console/features/platform/support_screen.dart'),
('source', 'package:swansport_console/features/platform/turf_fields_screen.dart'),
('source', 'package:swansport_console/features/schedule/attendance_providers.dart'),
('source', 'package:swansport_console/features/schedule/attendance_screen.dart'),
('source', 'package:swansport_console/features/schedule/facilities_screen.dart'),
('source', 'package:swansport_console/features/schedule/schedule_screen.dart'),
('source', 'package:swansport_console/features/schedule/series_dialog.dart'),
('source', 'package:swansport_console/main_development.dart'),
('source', 'package:swansport_console/main_production.dart'),
('source', 'package:swansport_core/color/contrast.dart'),
('source', 'package:swansport_core/config/app_env.dart'),
('source', 'package:swansport_core/config/supabase_config.dart'),
('source', 'package:swansport_core/errors/app_failure.dart'),
('source', 'package:swansport_core/logging/app_logger.dart'),
('source', 'package:swansport_core/result/app_result.dart'),
('source', 'package:swansport_core/swansport_core.dart'),
('source', 'package:swansport_core/text/tr_text.dart'),
('source', 'package:swansport_data/src/access.dart'),
('source', 'package:swansport_data/src/admin_service.dart'),
('source', 'package:swansport_data/src/athlete_profile_service.dart'),
('source', 'package:swansport_data/src/club_application_service.dart'),
('source', 'package:swansport_data/src/club_config_service.dart'),
('source', 'package:swansport_data/src/club_data.dart'),
('source', 'package:swansport_data/src/club_lifecycle_service.dart'),
('source', 'package:swansport_data/src/club_ops_service.dart'),
('source', 'package:swansport_data/src/club_profile_service.dart'),
('source', 'package:swansport_data/src/community_service.dart'),
('source', 'package:swansport_data/src/court_service.dart'),
('source', 'package:swansport_data/src/development_report.dart'),
('source', 'package:swansport_data/src/diagnostics.dart'),
('source', 'package:swansport_data/src/diagnostics_catalog.dart'),
('source', 'package:swansport_data/src/equipment_service.dart'),
('source', 'package:swansport_data/src/expense_service.dart'),
('source', 'package:swansport_data/src/feature_flags.dart'),
('source', 'package:swansport_data/src/finance_ops_service.dart'),
('source', 'package:swansport_data/src/finance_service.dart'),
('source', 'package:swansport_data/src/marketplace_service.dart'),
('source', 'package:swansport_data/src/moderation_service.dart'),
('source', 'package:swansport_data/src/money.dart'),
('source', 'package:swansport_data/src/network_service.dart'),
('source', 'package:swansport_data/src/news_service.dart'),
('source', 'package:swansport_data/src/notification_service.dart'),
('source', 'package:swansport_data/src/nutrition_service.dart'),
('source', 'package:swansport_data/src/offline/attendance_database_io.dart'),
('source', 'package:swansport_data/src/offline/attendance_database_web.dart'),
('source', 'package:swansport_data/src/offline_attendance.dart'),
('source', 'package:swansport_data/src/parent_actions.dart'),
('source', 'package:swansport_data/src/performance_service.dart'),
('source', 'package:swansport_data/src/saha_operations.dart'),
('source', 'package:swansport_data/src/season_setup.dart'),
('source', 'package:swansport_data/src/social_service.dart'),
('source', 'package:swansport_data/src/social_share_service.dart'),
('source', 'package:swansport_data/src/supabase_athletes.dart'),
('source', 'package:swansport_data/src/supabase_scope.dart'),
('source', 'package:swansport_data/src/training_session_service.dart'),
('source', 'package:swansport_data/src/turf_service.dart'),
('source', 'package:swansport_data/src/vault_service.dart'),
('source', 'package:swansport_data/src/verification_service.dart'),
('source', 'package:swansport_data/swansport_data.dart')
on conflict do nothing;
-- CATALOG END

create table if not exists public.diagnostic_sessions (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), last_seen timestamptz not null default now()
);
create table if not exists public.diagnostic_limits (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null default now(), event_count integer not null default 0
);
create table if not exists public.diagnostic_issues (
  id uuid primary key default gen_random_uuid(), fingerprint text unique not null,
  operation text not null, code text not null,
  state text not null default 'new' check(state in ('new','investigating','resolved','regressed')),
  occurrence_count bigint not null default 1,
  first_seen timestamptz not null default now(), last_seen timestamptz not null default now(),
  resolved_at timestamptz, resolved_by uuid references auth.users(id) on delete set null
);
create table if not exists public.diagnostic_events (
  session_id uuid not null references public.diagnostic_sessions(id) on delete cascade,
  id uuid not null, trace_id uuid not null, issue_id uuid references public.diagnostic_issues(id) on delete set null,
  kind text not null check(kind in ('screen','start','success','error','slow','cancel')),
  operation text not null, screen text not null, code text not null,
  release text not null, platform text not null, application text not null,
  usage_enabled boolean not null default false,
  duration_ms integer not null, occurred_at timestamptz not null,
  received_at timestamptz not null default now(), frames jsonb not null default '[]',
  breadcrumbs jsonb not null default '[]', primary key(session_id,id)
);
create index if not exists diagnostic_events_issue on public.diagnostic_events(issue_id,received_at desc);
create index if not exists diagnostic_events_recent on public.diagnostic_events(received_at desc);
create index if not exists diagnostic_events_trace on public.diagnostic_events(trace_id);
create table if not exists public.diagnostic_server_events (
  id uuid primary key default gen_random_uuid(), trace_id uuid not null,
  operation text not null, received_at timestamptz not null default now()
);
create index if not exists diagnostic_server_trace on public.diagnostic_server_events(trace_id);
create table if not exists public.diagnostic_alerts (
  id uuid primary key default gen_random_uuid(), code text not null, alert_key text not null,
  bucket timestamptz not null, qty integer not null,
  created_at timestamptz not null default now(), unique(code,alert_key,bucket)
);
create table if not exists public.support_diagnostic_links (
  ticket_id uuid primary key references public.support_tickets(id) on delete cascade,
  session_id uuid not null, snapshot jsonb not null,
  attachment_path text, created_at timestamptz not null default now()
);

-- No direct writes/reads, including the hidden identity/session mapping.
do $fn$ declare t text; begin
  foreach t in array array['diagnostic_sessions','diagnostic_limits','diagnostic_issues',
    'diagnostic_events','diagnostic_server_events','diagnostic_alerts','support_diagnostic_links'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public, anon, authenticated',t);
  end loop;
end $fn$;

-- Accept only safe code locations; free-form stack traces cannot reach storage.
create or replace function public.clean_diagnostic_event(p_event jsonb)
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
declare v jsonb; f jsonb; frames jsonb := '[]'; b jsonb; crumbs jsonb := '[]';
begin
  if jsonb_typeof(p_event) is distinct from 'object' then raise exception 'Invalid diagnostic event'; end if;
  if not exists(select 1 from diagnostic_catalog where category='route' and value=p_event->>'screen')
     or not exists(select 1 from diagnostic_catalog where category='operation' and value=p_event->>'operation') then
    raise exception 'Unknown diagnostic identifier';
  end if;
  if coalesce(p_event->>'kind','') not in ('screen','start','success','error','slow','cancel')
     or coalesce(p_event->>'code','') !~ '^(none|unknown|network_error|timeout|framework|async|provider|validation|consistency|http_[1-5][0-9]{2})$'
     or coalesce(p_event->>'release','') !~ '^(unknown|[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?)$'
     or coalesce(p_event->>'platform','') not in ('web','android','ios','windows','linux','macos','unknown')
     or coalesce(p_event->>'application','') not in ('app','console') then
    raise exception 'Invalid diagnostic metadata';
  end if;
  if jsonb_typeof(p_event->'duration_ms') is distinct from 'number' then raise exception 'Invalid duration'; end if;
  if (p_event->>'duration_ms')::numeric not between 0 and 600000
     or (p_event->>'duration_ms')::numeric <> trunc((p_event->>'duration_ms')::numeric) then
    raise exception 'Invalid duration'; end if;
  if jsonb_typeof(coalesce(p_event->'frames','[]')) is distinct from 'array' then raise exception 'Invalid frames'; end if;
  for f in select value from jsonb_array_elements(coalesce(p_event->'frames','[]')) limit 10 loop
    if exists(select 1 from diagnostic_catalog where category='source' and value=f->>'source') then
      if (case when jsonb_typeof(f->'line')='number' then (f->>'line')::numeric between 1 and 100000 else false end) then
        frames:=frames||jsonb_build_array(jsonb_build_object('source',f->>'source','line',(f->>'line')::integer));
      end if;
    end if;
  end loop;
  if jsonb_typeof(coalesce(p_event->'breadcrumbs','[]')) is distinct from 'array' then raise exception 'Invalid breadcrumbs'; end if;
  -- Recursive cleaning, bounded and with nested breadcrumbs forcibly removed.
  for b in select value from jsonb_array_elements(coalesce(p_event->'breadcrumbs','[]')) limit 30 loop
    crumbs:=crumbs||jsonb_build_array(public.clean_diagnostic_event(b-'breadcrumbs'));
  end loop;
  v:=jsonb_build_object('id',(p_event->>'id')::uuid,'trace_id',(p_event->>'trace_id')::uuid,
    'kind',p_event->>'kind','operation',p_event->>'operation','screen',p_event->>'screen',
    'code',p_event->>'code','release',p_event->>'release','platform',p_event->>'platform',
    'application',p_event->>'application','usage_enabled',coalesce(p_event->'usage_enabled'='true'::jsonb,false),'duration_ms',(p_event->>'duration_ms')::integer,
    'occurred_at',greatest(now()-interval '1 day',least(now(),(p_event->>'occurred_at')::timestamptz)),
    'frames',frames,'breadcrumbs',crumbs);
  if v->>'id' is null or v->>'trace_id' is null or v->>'occurred_at' is null then raise exception 'Missing event fields'; end if;
  return v;
end $fn$;
revoke all on function public.clean_diagnostic_event(jsonb) from public,anon,authenticated;

create or replace function public.ingest_diagnostics(p_session uuid,p_events jsonb)
returns integer language plpgsql security definer set search_path=public as $fn$
declare e jsonb; v jsonb; owner uuid; n integer; issue uuid; fp text; inserted integer; accepted integer:=0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_session is null or jsonb_typeof(p_events) is distinct from 'array' then raise exception 'Invalid batch'; end if;
  n:=jsonb_array_length(p_events);
  if n not between 1 and 20 or octet_length(p_events::text)>65536 then raise exception 'Batch limit exceeded'; end if;
  -- One locked counter per actor: concurrent sessions cannot bypass the hourly cap.
  insert into diagnostic_limits(owner_id) values(auth.uid()) on conflict do nothing;
  update diagnostic_limits set
    event_count=case when window_start < now()-interval '1 hour' then n else event_count+n end,
    window_start=case when window_start < now()-interval '1 hour' then now() else window_start end
    where owner_id=auth.uid() and (window_start<now()-interval '1 hour' or event_count+n<=1000);
  if not found then raise exception 'Diagnostic rate limit exceeded'; end if;
  insert into diagnostic_sessions(id,owner_id) values(p_session,auth.uid()) on conflict do nothing;
  select owner_id into owner from diagnostic_sessions where id=p_session for update;
  if owner is distinct from auth.uid() then raise exception 'Session access denied'; end if;
  update diagnostic_sessions set last_seen=now() where id=p_session;
  for e in select value from jsonb_array_elements(p_events) loop
    v:=public.clean_diagnostic_event(e);
    -- Session row serializes retries. Don't increment counts for duplicate IDs.
    if exists(select 1 from diagnostic_events where session_id=p_session and id=(v->>'id')::uuid) then continue; end if;
    issue:=null;
    if v->>'kind'='error' then
      fp:=md5(concat_ws('|',v->>'application',v->>'operation',v->>'screen',v->>'code',v->'frames'->0->>'source',v->'frames'->0->>'line'));
      insert into diagnostic_issues(fingerprint,operation,code)
      values(fp,v->>'operation',v->>'code')
      on conflict(fingerprint) do update set occurrence_count=diagnostic_issues.occurrence_count+1,
        last_seen=now(), state=case when diagnostic_issues.state='resolved'
          and (v->>'occurred_at')::timestamptz>diagnostic_issues.resolved_at then 'regressed' else diagnostic_issues.state end
      returning id into issue;
    end if;
    insert into diagnostic_events(session_id,id,trace_id,issue_id,kind,operation,screen,code,
      release,platform,application,usage_enabled,duration_ms,occurred_at,frames,breadcrumbs)
    values(p_session,(v->>'id')::uuid,(v->>'trace_id')::uuid,issue,v->>'kind',v->>'operation',v->>'screen',v->>'code',
      v->>'release',v->>'platform',v->>'application',(v->>'usage_enabled')::boolean,(v->>'duration_ms')::integer,(v->>'occurred_at')::timestamptz,v->'frames',v->'breadcrumbs');
    accepted:=accepted+1;
  end loop;
  return accepted;
end $fn$;
revoke all on function public.ingest_diagnostics(uuid,jsonb) from public,anon;
grant execute on function public.ingest_diagnostics(uuid,jsonb) to authenticated;

create or replace function public.admin_diagnostic_issues(p_status text default null,p_release text default null,
  p_platform text default null,p_screen text default null,p_offset integer default 0)
returns table(id uuid,operation text,code text,state text,occurrence_count bigint,session_count bigint,
  last_seen timestamptz,release text,platform text,screen text,total_count bigint)
language plpgsql stable security definer set search_path=public as $fn$
begin
  if not coalesce(public.is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
  return query with matching as (
    select i.id,i.operation,i.code,i.state,i.occurrence_count,i.last_seen,
      count(distinct e.session_id) as sessions
    from diagnostic_issues i join diagnostic_events e on e.issue_id=i.id
    where (p_status is null or i.state=p_status) and (p_release is null or e.release=p_release)
      and (p_platform is null or e.platform=p_platform) and (p_screen is null or e.screen=p_screen)
    group by i.id
  ) select m.id,m.operation,m.code,m.state,m.occurrence_count,m.sessions,m.last_seen,
      sample.release,sample.platform,sample.screen,count(*) over()
    from matching m cross join lateral (
      select e.release,e.platform,e.screen from diagnostic_events e where e.issue_id=m.id
        and (p_release is null or e.release=p_release) and (p_platform is null or e.platform=p_platform)
        and (p_screen is null or e.screen=p_screen) order by e.received_at desc limit 1
    ) sample order by m.last_seen desc,m.id limit 50 offset greatest(coalesce(p_offset,0),0);
end $fn$;

create or replace function public.admin_diagnostic_detail(p_issue uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
declare result jsonb;
begin
  if not coalesce(public.is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
  select jsonb_build_object('issue',to_jsonb(i),'events',coalesce((select jsonb_agg(to_jsonb(e)) from
    (select id,trace_id,session_id,kind,operation,screen,code,release,platform,application,duration_ms,occurred_at,frames,breadcrumbs
       from diagnostic_events where issue_id=i.id order by received_at desc limit 20) e),'[]'),
    'server_events',coalesce((select jsonb_agg(to_jsonb(s)) from (
      select s.trace_id,s.operation,s.received_at from diagnostic_server_events s
      where s.trace_id in (select trace_id from diagnostic_events where issue_id=i.id)
      order by s.received_at desc limit 50) s),'[]')) into result from diagnostic_issues i where i.id=p_issue;
  return result;
end $fn$;

create or replace function public.set_diagnostic_issue_status(p_issue uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $fn$
begin
  if not coalesce(public.is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
  if coalesce(p_status,'') not in ('investigating','resolved') then raise exception 'Invalid issue status'; end if;
  update diagnostic_issues set state=p_status,
    resolved_at=case when p_status='resolved' then now() else null end,
    resolved_by=case when p_status='resolved' then auth.uid() else null end where id=p_issue;
  if not found then raise exception 'Issue not found'; end if;
end $fn$;

create or replace function public.refresh_diagnostic_alerts()
returns void language plpgsql security definer set search_path=public as $fn$
declare v_bucket timestamptz := date_trunc('hour',now())+floor(extract(minute from now())/15)*interval '15 minutes';
begin
  insert into diagnostic_alerts(code,alert_key,bucket,qty)
    select 'recurring_error',issue_id::text,v_bucket,count(*)::integer from diagnostic_events
     where kind='error' and received_at>now()-interval '15 minutes' and issue_id is not null
     group by issue_id having count(*)>=3 on conflict(code,alert_key,bucket) do update set qty=excluded.qty;
  insert into diagnostic_alerts(code,alert_key,bucket,qty)
    select 'high_failure_rate',operation,v_bucket,count(*) filter(where kind='error')::integer from diagnostic_events
     where usage_enabled and kind in ('success','error') and received_at>now()-interval '15 minutes'
     group by operation having count(*)>=10 and count(*) filter(where kind='error')::numeric/count(*)>=0.2
     on conflict(code,alert_key,bucket) do update set qty=excluded.qty;
  insert into diagnostic_alerts(code,alert_key,bucket,qty)
    select 'slow_operation',operation,v_bucket,count(*)::integer from diagnostic_events
     where kind='slow' and received_at>now()-interval '15 minutes'
     group by operation having count(*)>=5 on conflict(code,alert_key,bucket) do update set qty=excluded.qty;
end $fn$;
revoke all on function public.refresh_diagnostic_alerts() from public,anon,authenticated;

-- Silent accounting failures are surfaced as aggregate counts only.
-- Reuse 0085's authoritative ledger validator; never copy amounts or athlete data.
create or replace function public.admin_diagnostic_consistency()
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
declare result jsonb;
begin
  if not coalesce(public.is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
  select jsonb_build_array(
    jsonb_build_object('code','invalid_financial_amount','count',count(*) filter(
      where a.amount<=0 or a.amount::text in ('NaN','Infinity','-Infinity'))),
    jsonb_build_object('code','unmatched_approved_adjustment','count',count(*) filter(
      where a.status='approved' and not public.finance_adjustment_entry_matches(a,
        case a.target_kind when 'expense' then e.account_id when 'payment' then p.account_id when 'donation' then d.account_id end)))
  ) into result from public.finance_adjustments a
    left join public.expenses e on a.target_kind='expense' and e.id=a.target_id and e.club_id=a.club_id
    left join public.payments p on a.target_kind='payment' and p.id=a.target_id and p.club_id=a.club_id
    left join public.donations d on a.target_kind='donation' and d.id=a.target_id and d.club_id=a.club_id;
  return result;
end $fn$;

create or replace function public.admin_diagnostic_overview()
returns jsonb language plpgsql security definer set search_path=public as $fn$
declare result jsonb;
begin
  if not coalesce(public.is_platform_admin(),false) then raise exception 'Platform admin required'; end if;
  perform public.refresh_diagnostic_alerts();
  select jsonb_build_object('consistency',public.admin_diagnostic_consistency(),'open_issues',(select count(*) from diagnostic_issues i where state<>'resolved' and exists(select 1 from diagnostic_events e where e.issue_id=i.id)),
    'errors_24h',(select count(*) from diagnostic_events where kind='error' and received_at>now()-interval '1 day'),
    'sessions_24h',(select count(distinct session_id) from diagnostic_events where received_at>now()-interval '1 day'),
    'alerts',coalesce((select jsonb_agg(to_jsonb(a)) from (select code,alert_key,qty,created_at from diagnostic_alerts
      where bucket>=now()-interval '1 hour' order by created_at desc limit 30) a),'[]'),
    'flows',coalesce((select jsonb_agg(to_jsonb(f)) from (select operation,
      count(*) filter(where kind='start') as started,count(*) filter(where kind='success') as succeeded,
      count(*) filter(where kind='error') as failed,round(avg(duration_ms) filter(where kind in ('success','error'))) as avg_ms
      from diagnostic_events where usage_enabled and received_at>now()-interval '1 day' and kind in ('start','success','error')
      group by operation order by count(*) filter(where kind='error') desc limit 20) f),'[]')) into result;
  return result;
end $fn$;

-- Header correlation at existing audited write paths. No row values or entity IDs are copied.
create or replace function public.diagnostic_server_trace()
returns trigger language plpgsql security definer set search_path=public as $fn$
declare trace text;
begin
  if auth.uid() is null then return new; end if;
  begin trace:=substring(nullif(current_setting('request.headers',true),'')::jsonb->>'x-client-info' from 'swan-trace=([0-9a-fA-F-]{36})');
  exception when others then return new; end;
  if coalesce(trace,'') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    -- Correlation is best effort and cannot prevent an audited business write.
    begin insert into diagnostic_server_events(trace_id,operation) values(trace::uuid,tg_argv[0]);
    exception when others then null; end;
  end if;
  return new;
end $fn$;
revoke all on function public.diagnostic_server_trace() from public,anon,authenticated;
do $fn$ declare t text; begin
  foreach t in array array['finance_period_logs','expense_audit_logs','attendance_op_logs','support_tickets'] loop
    if to_regclass('public.'||t) is not null then
      execute format('drop trigger if exists diagnostic_trace on public.%I',t);
      execute format('create trigger diagnostic_trace after insert on public.%I for each row execute function public.diagnostic_server_trace(%L)',t,t);
    end if;
  end loop;
end $fn$;

create or replace function public.link_support_diagnostics(p_ticket uuid,p_session uuid,p_snapshot jsonb,p_attachment text default null)
returns void language plpgsql security definer set search_path=public as $fn$
declare owner uuid; e jsonb; events jsonb:='[]'; snapshot jsonb;
begin
  select profile_id into owner from support_tickets where id=p_ticket;
  if owner is distinct from auth.uid() or auth.uid() is null then raise exception 'Ticket access denied'; end if;
  if p_session is null or jsonb_typeof(p_snapshot) is distinct from 'object' or octet_length(p_snapshot::text)>65536 then
    raise exception 'Invalid support snapshot'; end if;
  if exists(select 1 from diagnostic_sessions where id=p_session and owner_id<>auth.uid()) then
    raise exception 'Session access denied'; end if;
  if jsonb_typeof(coalesce(p_snapshot->'events','[]')) is distinct from 'array' then raise exception 'Invalid support events'; end if;
  for e in select value from jsonb_array_elements(coalesce(p_snapshot->'events','[]')) limit 30 loop
    events:=events||jsonb_build_array(public.clean_diagnostic_event(e-'breadcrumbs'));
  end loop;
  if p_attachment is not null and (p_attachment not like auth.uid()::text||'/'||p_ticket::text||'/%'
    or p_attachment ~ '\.\.' or not exists(select 1 from storage.objects where bucket_id='diagnostic-attachments' and name=p_attachment)) then
    raise exception 'Attachment access denied'; end if;
  snapshot:=jsonb_build_object('session_id',p_session,'events',events,
    'screen',case when exists(select 1 from diagnostic_catalog where category='route' and value=p_snapshot->>'screen') then p_snapshot->>'screen' else '/unknown' end,
    'release',case when coalesce(p_snapshot->>'release','')~'^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$' then p_snapshot->>'release' else 'unknown' end,
    'platform',case when coalesce(p_snapshot->>'platform','') in ('web','android','ios','windows','linux','macos') then p_snapshot->>'platform' else 'unknown' end);
  insert into support_diagnostic_links(ticket_id,session_id,snapshot,attachment_path)
  values(p_ticket,p_session,snapshot,p_attachment) on conflict(ticket_id) do update
    set session_id=excluded.session_id,snapshot=excluded.snapshot,attachment_path=excluded.attachment_path;
end $fn$;

create or replace function public.support_diagnostic_context(p_ticket uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
declare owner uuid; result jsonb;
begin
  select profile_id into owner from support_tickets where id=p_ticket;
  if auth.uid() is null or not coalesce(owner=auth.uid() or public.is_platform_admin(),false) then raise exception 'Ticket access denied'; end if;
  select jsonb_build_object('snapshot',snapshot,'attachment_path',attachment_path) into result
    from support_diagnostic_links where ticket_id=p_ticket and created_at>now()-interval '30 days';
  return result;
end $fn$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('diagnostic-attachments','diagnostic-attachments',false,5242880,array['image/png','image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=array['image/png','image/jpeg'];
drop policy if exists diagnostic_attachment_insert on storage.objects;
create policy diagnostic_attachment_insert on storage.objects for insert to authenticated with check(
  bucket_id='diagnostic-attachments' and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.png$'
  and split_part(name,'/',1)=auth.uid()::text
  and exists(select 1 from public.support_tickets t where t.id::text=split_part(name,'/',2) and t.profile_id=auth.uid())
);
drop policy if exists diagnostic_attachment_read on storage.objects;
create policy diagnostic_attachment_read on storage.objects for select to authenticated using(
  bucket_id='diagnostic-attachments' and created_at>now()-interval '30 days' and (split_part(name,'/',1)=auth.uid()::text or public.is_platform_admin())
);

-- Finite retention; diagnostics is not an accounting audit trail.
create or replace function public.purge_diagnostics()
returns void language plpgsql security definer set search_path=public as $fn$
begin
  delete from diagnostic_events where received_at<now()-interval '30 days';
  delete from diagnostic_server_events where received_at<now()-interval '30 days';
  delete from diagnostic_sessions where last_seen<now()-interval '30 days';
  delete from diagnostic_alerts where created_at<now()-interval '30 days';
  delete from diagnostic_issues where last_seen<now()-interval '90 days';
  delete from diagnostic_limits where window_start<now()-interval '1 day';
  delete from support_diagnostic_links where created_at<now()-interval '30 days' and attachment_path is null;
  update support_diagnostic_links set snapshot='{}' where created_at<now()-interval '30 days';
end $fn$;
revoke all on function public.purge_diagnostics() from public,anon,authenticated;

-- Physical object removal must go through Storage API, never DELETE storage.objects.
-- A service worker removes these paths then acknowledges the completed deletion.
create or replace function public.pending_diagnostic_attachments()
returns table(path text) language sql stable security definer set search_path=public as $fn$
  select name from storage.objects where bucket_id='diagnostic-attachments'
    and created_at<now()-interval '30 days' order by created_at limit 100;
$fn$;
create or replace function public.ack_diagnostic_attachment_cleanup(p_path text)
returns void language sql security definer set search_path=public as $fn$
  delete from support_diagnostic_links where attachment_path=p_path
    and created_at<now()-interval '30 days';
$fn$;
revoke all on function public.pending_diagnostic_attachments() from public,anon,authenticated;
revoke all on function public.ack_diagnostic_attachment_cleanup(text) from public,anon,authenticated;
grant execute on function public.pending_diagnostic_attachments() to service_role;
grant execute on function public.ack_diagnostic_attachment_cleanup(text) to service_role;

do $fn$ declare signature text; begin
  foreach signature in array array[
    'admin_diagnostic_issues(text,text,text,text,integer)','admin_diagnostic_detail(uuid)',
    'set_diagnostic_issue_status(uuid,text)','admin_diagnostic_overview()','admin_diagnostic_consistency()',
    'link_support_diagnostics(uuid,uuid,jsonb,text)','support_diagnostic_context(uuid)'] loop
    execute 'revoke all on function public.'||signature||' from public,anon';
    execute 'grant execute on function public.'||signature||' to authenticated';
  end loop;
end $fn$;

do $fn$ begin
  if exists(select 1 from pg_namespace where nspname='cron') then
    execute $sql$select cron.schedule('swansport_diagnostic_alerts','*/15 * * * *','select public.refresh_diagnostic_alerts()')$sql$;
    execute $sql$select cron.schedule('swansport_diagnostic_retention','23 3 * * *','select public.purge_diagnostics()')$sql$;
  end if;
end $fn$;

-- User-facing help accompanies the new opt-in diagnostic/support controls.
insert into public.faq_entries(question,answer,category,audience,sort_order,route)
select v.* from (values
  ('Hata ve kullanım kayıtlarını nasıl açıp kapatırım?',
   'Profil içindeki Gizlilik ve Hesap ekranından hata tanılamasını ve kullanım ölçümünü ayrı ayrı açabilirsin. İkisi de varsayılan olarak kapalıdır. Mesajlar, form içerikleri, belgeler ve para tutarları otomatik toplanmaz. Kapatınca cihazdaki bekleyen teknik kayıtlar silinir. Teknik olaylar 30 günlük saklama süresiyle günlük temizlenir.',
   'Destek','everyone',170,'/gizlilik'),
  ('Bir hatayı teknik bilgi veya ekran görüntüsüyle nasıl bildiririm?',
   'Destek ekranında Sorun bildir seçeneğini aç. Konuyu ve ne olduğunu yaz. Teknik bilgileri bu talebe ekle seçeneği yalnızca bu talep için geçerlidir. İstersen özel bilgileri gizlediğin bir PNG veya JPEG ekran görüntüsü ekleyebilirsin. Görsel otomatik çekilmez. Teknik ekler gönderilemezse tekrar denemek yeni talep oluşturmaz.',
   'Destek','everyone',180,'/destek')
) as v(question,answer,category,audience,sort_order,route)
where not exists(select 1 from public.faq_entries f where f.question=v.question);
