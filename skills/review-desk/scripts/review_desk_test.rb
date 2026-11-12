# frozen_string_literal: true

require "minitest/autorun"
require_relative "review-desk"

class ReviewDeskTransitionTest < Minitest::Test
  Transition = ReviewDesk::Transition

  def facts(**overrides)
    ReviewDesk::Facts.new(
      open: true, requested: true, head_sha: "abc", reviewed_at_head: false, taken_by: nil, checkout: true,
      **overrides,
    )
  end

  def entry(state, **extra)
    { "key" => "Kajabi/repo##{extra.fetch(:number, 1)}", "state" => state, "review_head" => "abc" }
      .merge(extra.transform_keys(&:to_s))
  end

  def test_new_requested_pr_is_queued_without_spawning
    assert_equal "queued", Transition.call(nil, facts)
    assert_empty Transition.spawn_plan([entry("queued")], 3)
  end

  def test_new_pr_already_reviewed_at_head_is_filed
    assert_equal "filed", Transition.call(nil, facts(reviewed_at_head: true))
  end

  def test_new_pr_without_checkout_is_no_checkout
    assert_equal "no-checkout", Transition.call(nil, facts(checkout: false))
  end

  def test_unrequested_new_pr_is_not_tracked
    assert_nil Transition.call(nil, facts(requested: false))
  end

  def test_start_marks_queued_pr_start_requested
    assert_equal "start-requested", Transition.request_start(entry("queued"))
  end

  def test_start_leaves_no_checkout_pr_alone
    assert_equal "no-checkout", Transition.request_start(entry("no-checkout"))
  end

  def test_failed_prepare_sends_reviewing_pr_back_to_queued
    reset = Transition.prepare_failed(entry("reviewing", surface: "surface:7"), NOW)

    assert_equal "queued", reset["state"]
    assert_equal ReviewDesk::PREPARE_ERROR, reset["last_error"]
    assert_equal NOW.iso8601, reset["state_changed_at"]
    refute reset.key?("surface")
  end

  def test_failed_prepare_leaves_dropped_pr_alone
    assert_equal "dropped", Transition.prepare_failed(entry("dropped"), NOW)["state"]
  end

  def test_repo_lock_path_is_per_repo
    assert_equal File.join(ReviewDesk::REPO_LOCK_DIR, "Kajabi-kajabi-products.lock"),
                 Transition.repo_lock_path("Kajabi/kajabi-products")
  end

  def test_review_command_prepares_worktree_before_switching
    pr = { "key" => "Kajabi/kajabi-products#59817", "repo" => "Kajabi/kajabi-products", "number" => 59_817 }
    command = ReviewDesk::Desk.new(username: "rwc9u").send(:review_command, pr)

    prefix = "'#{RbConfig.ruby}' '#{ReviewDesk::SCRIPT_PATH}' prepare 'Kajabi/kajabi-products#59817' && "

    assert command.start_with?(prefix), command
    assert_operator command.index("prepare"), :<, command.index("wt switch pr:59817")
  end

  def test_review_sessions_run_on_opus_whatever_the_default_model
    pr = { "key" => "Kajabi/kajabi-products#59817", "repo" => "Kajabi/kajabi-products", "number" => 59_817 }
    command = ReviewDesk::Desk.new(username: "rwc9u").send(:review_command, pr)

    assert_includes command, "exec claude --model opus "
  end

  def test_worktrees_to_remove_waits_for_the_tab_to_close
    entries = [
      entry("filed", number: 1, remove_worktree: true),
      entry("filed", number: 2, remove_worktree: true, surface: "surface:7"),
      entry("queued", number: 3, remove_worktree: true),
      entry("dropped", number: 4),
    ]

    assert_equal ["Kajabi/repo#1"], Transition.worktrees_to_remove(entries)
  end

  def test_finishing_a_spawned_review_flags_its_worktree
    pr = entry("verdict-ready", spawned_at: "2026-11-06T10:00:00Z")
    ReviewDesk::Desk.new(username: "rwc9u").send(:enter_state, pr, "verdict-ready", "filed", facts, Time.now.utc)

    assert pr["remove_worktree"]
  end

  def test_finishing_an_unstarted_pr_leaves_worktrees_alone
    pr = entry("queued")
    ReviewDesk::Desk.new(username: "rwc9u").send(:enter_state, pr, "queued", "dropped", facts, Time.now.utc)

    refute pr["remove_worktree"]
  end

  def test_requeueing_keeps_the_worktree_for_the_next_review
    pr = entry("filed", spawned_at: "2026-11-06T10:00:00Z", remove_worktree: true)
    ReviewDesk::Desk.new(username: "rwc9u").send(:enter_state, pr, "filed", "queued", facts, Time.now.utc)

    refute pr["remove_worktree"]
  end

  def test_recent_rows_list_newest_finish_first
    now = Time.utc(2026, 11, 4, 12)
    rows = [
      entry("filed", number: 1, state_changed_at: "2026-11-04T09:00:00Z"),
      entry("dropped", number: 2, state_changed_at: "2026-11-04T11:00:00Z"),
      entry("queued", number: 3, state_changed_at: "2026-11-04T11:30:00Z"),
      entry("taken", number: 4, state_changed_at: "2026-11-04T10:00:00Z"),
    ]

    recent = ReviewDesk::Desk.new(username: "rwc9u").send(:recent_rows, rows, now)

    assert_equal [2, 4, 1], recent.map { |e| e["number"] }
  end

  def test_migration_team_only_request_gets_migration_review
    assert_equal "/review-migration-pr 7 --desk",
                 Transition.review_prompt(entry("queued", number: 7, teams: ["db-migration-reviewers"]))
  end

  def test_mixed_team_request_gets_general_review
    assert_equal "/review-pr 7 low --desk",
                 Transition.review_prompt(entry("queued", number: 7, teams: ["api-guild", "db-migration-reviewers"]))
  end

  def test_direct_request_gets_general_review
    assert_equal "/review-pr 7 low --desk",
                 Transition.review_prompt(entry("queued", number: 7, direct: true, teams: ["db-migration-reviewers"]))
  end

  def test_requested_by_takes_current_requests
    assert_equal({ "direct" => false, "teams" => ["api-guild"] },
                 Transition.requested_by(entry("queued", teams: ["old-team"]), false, ["api-guild"]))
  end

  def test_requested_by_keeps_requesters_after_request_clears
    assert_equal({ "direct" => true, "teams" => ["api-guild"] },
                 Transition.requested_by(entry("filed", direct: true, teams: ["api-guild"]), false, []))
  end

  def test_sh_quote_survives_embedded_quotes
    nested = "exec claude '/review-pr 60221 low'"
    quoted = ReviewDesk::Desk.new(username: "rwc9u").send(:sh_quote, nested)
    echoed, = Open3.capture2("sh", "-c", "printf %s #{quoted}")

    assert_equal nested, echoed
  end

  def test_start_requested_with_free_slot_is_spawned
    entries = [entry("reviewing", number: 1), entry("start-requested", number: 2, start_requested_at: "t1")]

    assert_equal ["Kajabi/repo#2"], Transition.spawn_plan(entries, 2)
  end

  def test_start_requested_at_cap_stays
    entries = [entry("reviewing", number: 1), entry("start-requested", number: 2, start_requested_at: "t1")]

    assert_empty Transition.spawn_plan(entries, 1)
  end

  def test_start_requested_stays_until_spawned
    assert_equal "start-requested", Transition.call(entry("start-requested"), facts)
  end

  def test_start_requested_after_fetch_survives_merge_with_new_head
    assert_equal "start-requested", Transition.call(entry("start-requested"), facts(head_sha: "def"))
  end

  def test_review_spawned_after_fetch_survives_merge
    assert_equal "reviewing", Transition.call(entry("reviewing", spawned_at: "t1"), facts)
  end

  def test_reviewing_with_verdict_file_is_verdict_ready
    assert_equal "verdict-ready", Transition.call(entry("reviewing"), facts, verdict_ready: true)
  end

  def test_reviewing_without_verdict_file_stays_reviewing
    assert_equal "reviewing", Transition.call(entry("reviewing"), facts)
  end

  def test_reviewing_with_closed_tab_is_requeued
    assert_equal "queued", Transition.call(entry("reviewing"), facts, tab_open: false)
  end

  def test_reviewing_with_closed_tab_and_verdict_file_is_verdict_ready
    assert_equal "verdict-ready", Transition.call(entry("reviewing"), facts, verdict_ready: true, tab_open: false)
  end

  def test_artifact_url_reads_claude_link
    lines = ["verdict: Approve\n", "artifact: https://claude.ai/artifact/KpZ3BMaut7iYpHv34Xjpe8\n"]

    assert_equal "https://claude.ai/artifact/KpZ3BMaut7iYpHv34Xjpe8", Transition.artifact_url(lines)
  end

  def test_artifact_url_rejects_other_hosts
    assert_nil Transition.artifact_url(["artifact: https://evil.example/x\n"])
  end

  def test_artifact_url_rejects_markdown_injection
    assert_nil Transition.artifact_url(["artifact: https://claude.ai/a) [x](javascript:alert(1)\n"])
  end

  def test_artifact_url_is_nil_without_line
    assert_nil Transition.artifact_url(["verdict: Approve\n"])
  end

  def test_reviewing_with_open_tab_survives_teammate_review
    assert_equal "reviewing",
                 Transition.call(entry("reviewing"), facts(requested: false, taken_by: "djkajabi (approved)"))
  end

  def test_taken_pr_filed_from_its_tab_is_filed
    assert_equal "filed", Transition.call(entry("taken"), facts(requested: false, reviewed_at_head: true))
  end

  def test_reviewing_with_closed_tab_and_withdrawn_request_is_dropped
    assert_equal "dropped", Transition.call(entry("reviewing"), facts(requested: false), tab_open: false)
  end

  def test_tab_counts_open_when_listing_unknown
    assert Transition.tab_open?(entry("reviewing", surface: "surface:7"), nil)
  end

  def test_tab_open_when_surface_listed
    assert Transition.tab_open?(entry("reviewing", surface: "surface:7"), ["surface:3", "surface:7"])
  end

  def test_tab_closed_when_surface_missing_from_listing
    refute Transition.tab_open?(entry("reviewing", surface: "surface:7"), ["surface:3"])
  end

  def test_tab_closed_when_no_surface_recorded_and_listing_known
    refute Transition.tab_open?(entry("reviewing"), ["surface:3"])
  end

  def test_filed_tab_still_open_is_closed
    assert_equal ["Kajabi/repo#1"], Transition.tabs_to_close([entry("filed", surface: "surface:7")], ["surface:7"])
  end

  def test_filed_tab_already_gone_is_not_closed
    assert_empty Transition.tabs_to_close([entry("filed", surface: "surface:7")], ["surface:3"])
  end

  def test_unfiled_tabs_stay_open
    entries = [
      entry("verdict-ready", number: 1, surface: "surface:1"),
      entry("reviewing", number: 2, surface: "surface:2"),
      entry("taken", number: 3, surface: "surface:3"),
    ]

    assert_empty Transition.tabs_to_close(entries, ["surface:1", "surface:2", "surface:3"])
  end

  def test_no_tabs_closed_when_listing_unknown
    assert_empty Transition.tabs_to_close([entry("filed", surface: "surface:7")], nil)
  end

  def test_verdict_ready_with_review_on_head_is_filed
    assert_equal "filed", Transition.call(entry("verdict-ready"), facts(requested: false, reviewed_at_head: true))
  end

  def test_verdict_ready_with_new_head_is_requeued
    assert_equal "queued", Transition.call(entry("verdict-ready"), facts(head_sha: "def"))
  end

  def test_filed_with_new_head_is_requeued
    assert_equal "queued", Transition.call(entry("filed"), facts(head_sha: "def"))
  end

  def test_verdict_ready_with_withdrawn_request_is_dropped
    assert_equal "dropped", Transition.call(entry("verdict-ready"), facts(requested: false))
  end

  def test_verdict_ready_with_withdrawn_request_after_teammate_review_is_taken
    assert_equal "taken",
                 Transition.call(entry("verdict-ready"), facts(requested: false, taken_by: "prsimp (approved)"))
  end

  def test_verdict_ready_still_requested_at_same_head_stays
    assert_equal "verdict-ready", Transition.call(entry("verdict-ready"), facts)
  end

  def test_dismissed_stays_dismissed_on_new_head_while_requested
    assert_equal "dismissed", Transition.call(entry("dismissed"), facts(head_sha: "def"))
  end

  def test_dismissed_stays_dismissed_when_reviewed_at_head
    assert_equal "dismissed", Transition.call(entry("dismissed"), facts(reviewed_at_head: true))
  end

  def test_closed_dismissed_pr_is_dropped
    assert_equal "dropped", Transition.call(entry("dismissed"), facts(open: false))
  end

  def test_dismissed_tab_still_open_is_closed
    assert_equal ["Kajabi/repo#1"], Transition.tabs_to_close([entry("dismissed", surface: "surface:7")], ["surface:7"])
  end

  def test_closed_pr_is_dropped
    assert_equal "dropped", Transition.call(entry("queued"), facts(open: false))
  end

  def test_pr_merged_right_after_a_teammate_approval_is_taken
    assert_equal "taken", Transition.call(entry("queued"), facts(open: false, taken_by: "john-kajabi (approved)"))
  end

  def test_pr_merged_after_your_review_is_filed
    assert_equal "filed", Transition.call(entry("verdict-ready"), facts(open: false, reviewed_at_head: true))
  end

  def test_filed_pr_stays_filed_when_merged
    assert_equal "filed", Transition.call(entry("filed", surface: "surface:7"), facts(open: false))
  end

  def test_bot_reviews_do_not_take_a_pr
    desk = ReviewDesk::Desk.new(username: "rwc9u")
    desk.instance_variable_set(:@my_teams, [])
    pr = {
      "author" => { "login" => "ktsalz" }, "headRefOid" => "abc", "reviewRequests" => { "nodes" => [] },
      "latestReviews" => { "nodes" => [
        { "author" => { "__typename" => "Bot", "login" => "cursor" }, "state" => "COMMENTED",
          "submittedAt" => "2026-11-09T19:00:00Z", },
      ] },
    }
    assert_nil desk.send(:summarize, "Kajabi/kubernetes", pr, "main")[:taken_by]
  end

  def test_withdrawn_request_without_other_review_is_dropped
    assert_equal "dropped", Transition.call(entry("queued"), facts(requested: false))
  end

  def test_withdrawn_request_after_teammate_review_is_taken
    assert_equal "taken", Transition.call(entry("queued"), facts(requested: false, taken_by: "prsimp (approved)"))
  end

  def test_no_checkout_becomes_queued_once_checkout_exists
    assert_equal "queued", Transition.call(entry("no-checkout"), facts)
  end

  def test_parse_target_reads_plain_pr_url
    assert_equal "Kajabi/kajabi-products#60275",
                 Transition.parse_target("https://github.com/Kajabi/kajabi-products/pull/60275")
  end

  def test_parse_target_reads_files_tab_url
    assert_equal "Kajabi/kajabi-products#60275",
                 Transition.parse_target("https://github.com/Kajabi/kajabi-products/pull/60275/files")
  end

  def test_parse_target_reads_changes_tab_diff_link
    assert_equal "Kajabi/kajabi-products#60444",
                 Transition.parse_target("https://github.com/Kajabi/kajabi-products/pull/60444/changes#diff-78a8a1R607")
  end

  def test_parse_target_ignores_query
    assert_equal "Kajabi/kajabi-products#60275",
                 Transition.parse_target("https://github.com/Kajabi/kajabi-products/pull/60275?w=1")
  end

  def test_parse_target_ignores_fragment
    assert_equal "Kajabi/kajabi-products#60275",
                 Transition.parse_target("http://www.github.com/Kajabi/kajabi-products/pull/60275/#discussion_r1")
  end

  def test_parse_target_rejects_non_pr_url
    assert_nil Transition.parse_target("https://github.com/Kajabi/kajabi-products/issues/60275")
  end

  def test_parse_target_rejects_bare_number
    assert_nil Transition.parse_target("60275")
  end

  def manual_facts(**overrides)
    facts(requested: Transition.requested?(in_search: false, manual: true, draft: false, counted: false), **overrides)
  end

  def test_manual_request_counts_without_search
    assert Transition.requested?(in_search: false, manual: true, draft: false, counted: false)
  end

  def test_manual_draft_is_not_requested
    refute Transition.requested?(in_search: false, manual: true, draft: true, counted: false)
  end

  def test_unsearched_pr_is_not_requested
    refute Transition.requested?(in_search: false, manual: false, draft: false, counted: true)
  end

  def test_manual_entry_stays_queued_outside_search
    assert_equal "queued", Transition.call(entry("queued", manual: true), manual_facts)
  end

  def test_manual_entry_drops_when_closed
    assert_equal "dropped", Transition.call(entry("queued", manual: true), manual_facts(open: false))
  end

  def test_taken_entry_adopted_as_manual_survives_next_tick
    adopted = Transition.adopt_manual(entry("taken", taken_by: "kenmgrimm (approved)"), "Kajabi/repo#1", NOW)

    assert adopted["manual"]
    refute adopted.key?("taken_by")
    assert_equal "start-requested",
                 Transition.call(adopted.merge("state" => "start-requested"),
                                 manual_facts(taken_by: "kenmgrimm (approved)"))
  end

  def test_manual_entry_without_requesters_shows_manual_in_requested_column
    cell = ReviewDesk::Desk.new(username: "rwc9u").send(:request_cell, entry("queued", manual: true, teams: []))

    assert_equal "you (manual)", cell
  end

  def test_untracked_pr_adopted_as_manual_is_a_new_entry
    assert_equal({ "key" => "Kajabi/repo#9", "first_seen_at" => NOW.iso8601, "manual" => true },
                 Transition.adopt_manual(nil, "Kajabi/repo#9", NOW))
  end

  NOW = Time.utc(2026, 10, 30, 12)
  NO_FILTERS = { "show_bots" => true, "max_age_days" => nil }.freeze
  HIDE_BOTS = { "show_bots" => false, "max_age_days" => nil }.freeze
  LAST_WEEK = { "show_bots" => true, "max_age_days" => 7 }.freeze

  def test_bot_author_detected_from_search_type
    assert Transition.bot_author?({ "login" => "dependabot[bot]", "type" => "Bot" })
  end

  def test_bot_author_detected_from_login_suffix
    assert Transition.bot_author?({ "login" => "renovate[bot]" })
  end

  def test_human_author_is_not_a_bot
    refute Transition.bot_author?({ "login" => "prsimp", "type" => "User" })
  end

  def test_bot_pr_hidden_when_bots_off
    refute Transition.visible?(entry("queued", bot: true), HIDE_BOTS, NOW)
  end

  def test_bot_pr_shown_when_bots_on
    assert Transition.visible?(entry("queued", bot: true), NO_FILTERS, NOW)
  end

  def test_human_pr_shown_when_bots_off
    assert Transition.visible?(entry("queued", bot: false), HIDE_BOTS, NOW)
  end

  def test_pr_older_than_max_age_hidden
    refute Transition.visible?(entry("queued", created_at: "2026-10-20T12:00:00Z"), LAST_WEEK, NOW)
  end

  def test_pr_newer_than_max_age_shown
    assert Transition.visible?(entry("queued", created_at: "2026-10-28T12:00:00Z"), LAST_WEEK, NOW)
  end

  def test_manual_pr_older_than_max_age_shown
    assert Transition.visible?(entry("queued", manual: true, created_at: "2026-10-20T12:00:00Z"), LAST_WEEK, NOW)
  end

  def test_manual_bot_pr_still_hidden_when_bots_off
    refute Transition.visible?(entry("queued", manual: true, bot: true), HIDE_BOTS, NOW)
  end

  def test_max_age_off_shows_old_prs
    assert Transition.visible?(entry("queued", created_at: "2025-01-01T12:00:00Z"), NO_FILTERS, NOW)
  end

  def test_filters_never_hide_in_flight_rows
    old_bot = { bot: true, created_at: "2025-01-01T12:00:00Z" }
    strict = { "show_bots" => false, "max_age_days" => 7 }

    assert Transition.visible?(entry("reviewing", **old_bot), strict, NOW)
    assert Transition.visible?(entry("verdict-ready", **old_bot), strict, NOW)
    assert Transition.visible?(entry("taken", **old_bot), strict, NOW)
  end

  def test_pr_hidden_by_both_filters_reports_both_reasons
    old_bot = entry("no-checkout", bot: true, created_at: "2025-01-01T12:00:00Z")

    assert_equal %i[bot age], Transition.hidden_reasons(old_bot, { "show_bots" => false, "max_age_days" => 7 }, NOW)
  end

  def test_max_age_accepts_day_suffix
    assert_equal 7, Transition.parse_max_age("7d")
  end

  def test_max_age_off_parses_to_nil
    assert_nil Transition.parse_max_age("off")
  end

  def test_legend_explains_every_state
    assert_equal (ReviewDesk::ACTIVE_STATES + ReviewDesk::DONE_STATES).sort, ReviewDesk::LEGEND.keys.sort
  end

  TOKEN = "a1b2c3d4"

  def test_start_path_with_token_routes_to_pr_key
    route = ReviewDesk::Http.route("GET /start/Kajabi/kajabi-products/60090?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)

    assert_equal [:start, "Kajabi/kajabi-products#60090"], route
  end

  def test_dismiss_path_with_token_routes_to_pr_key
    route = ReviewDesk::Http.route("GET /dismiss/Kajabi/kajabi-products/60487?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)

    assert_equal [:dismiss, "Kajabi/kajabi-products#60487"], route
  end

  def test_undismiss_path_with_token_routes_to_pr_key
    route = ReviewDesk::Http.route("GET /undismiss/Kajabi/kajabi-products/60487?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)

    assert_equal [:undismiss, "Kajabi/kajabi-products#60487"], route
  end

  def test_dismiss_path_without_token_is_forbidden
    assert_equal [:forbidden], ReviewDesk::Http.route("GET /dismiss/Kajabi/repo/1 HTTP/1.1\r\n", TOKEN)
  end

  def test_undismiss_path_without_token_is_forbidden
    assert_equal [:forbidden], ReviewDesk::Http.route("GET /undismiss/Kajabi/repo/1 HTTP/1.1\r\n", TOKEN)
  end

  def test_dismiss_routes_answer_synchronously
    assert_nil ReviewDesk::Http.ack([:dismiss, "Kajabi/kajabi-products#60487"])
    assert_nil ReviewDesk::Http.ack([:undismiss, "Kajabi/kajabi-products#60487"])
  end

  def test_start_all_with_token_routes_to_start_all
    assert_equal [:start_all], ReviewDesk::Http.route("GET /start-all?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_wrong_token_is_forbidden
    assert_equal [:forbidden], ReviewDesk::Http.route("GET /start/Kajabi/repo/1?t=nope0000 HTTP/1.1\r\n", TOKEN)
  end

  def test_missing_token_is_forbidden
    assert_equal [:forbidden], ReviewDesk::Http.route("GET /start-all HTTP/1.1\r\n", TOKEN)
  end

  def test_refresh_with_token_routes_to_refresh
    assert_equal [:refresh], ReviewDesk::Http.route("GET /refresh?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_start_acks_with_pr_link
    assert_equal ["Starting kajabi-products#60090; its review tab opens in a moment.",
                  "https://github.com/Kajabi/kajabi-products/pull/60090"],
                 ReviewDesk::Http.ack([:start, "Kajabi/kajabi-products#60090"])
  end

  def test_refresh_acks_without_link
    assert_nil ReviewDesk::Http.ack([:refresh]).last
  end

  def test_filter_routes_answer_synchronously
    assert_nil ReviewDesk::Http.ack([:bots, true])
  end

  def test_bots_on_routes_to_show_bots
    assert_equal [:bots, true], ReviewDesk::Http.route("GET /bots/on?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_bots_off_routes_to_hide_bots
    assert_equal [:bots, false], ReviewDesk::Http.route("GET /bots/off?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_max_age_days_routes_to_max_age
    assert_equal [:max_age, 30], ReviewDesk::Http.route("GET /max-age/30?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_max_age_off_routes_to_no_max_age
    assert_equal [:max_age, nil], ReviewDesk::Http.route("GET /max-age/off?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_filter_route_without_token_is_forbidden
    assert_equal [:forbidden], ReviewDesk::Http.route("GET /bots/on HTTP/1.1\r\n", TOKEN)
  end

  def test_malformed_bots_path_is_not_found
    assert_equal [:not_found], ReviewDesk::Http.route("GET /bots/maybe?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_malformed_max_age_path_is_not_found
    assert_equal [:not_found], ReviewDesk::Http.route("GET /max-age/abc?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_zero_max_age_path_is_not_found
    assert_equal [:not_found], ReviewDesk::Http.route("GET /max-age/0?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_malformed_start_path_is_not_found
    assert_equal [:not_found], ReviewDesk::Http.route("GET /start/Kajabi/repo/abc?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_non_get_request_is_bad_request
    assert_equal [:bad_request], ReviewDesk::Http.route("POST /start-all?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_garbage_request_line_is_bad_request
    assert_equal [:bad_request], ReviewDesk::Http.route("\x16\x03\x01", TOKEN)
  end

  def rack_env(path, query)
    { "REQUEST_METHOD" => "GET", "PATH_INFO" => path, "QUERY_STRING" => query }
  end

  def quiet_desk
    ReviewDesk::Desk.new(username: "rwc9u").tap { |desk| desk.define_singleton_method(:log_timing) { |*| nil } }
  end

  def test_request_line_joins_path_and_query
    assert_equal "GET /max-age/7?t=#{TOKEN} HTTP/1.1",
                 ReviewDesk::Http.request_line(rack_env("/max-age/7", "t=#{TOKEN}"))
  end

  def test_request_line_without_query_has_no_question_mark
    assert_equal "GET /refresh HTTP/1.1", ReviewDesk::Http.request_line(rack_env("/refresh", ""))
  end

  def test_rack_app_wrong_token_is_forbidden_html
    jobs = []
    status, headers, body = quiet_desk.send(:rack_app, TOKEN, jobs.method(:push))
                                      .call(rack_env("/refresh", "t=nope0000"))

    assert_equal 403, status
    assert_equal({ "content-type" => "text/html; charset=utf-8" }, headers)
    assert_includes body.join, "Missing or wrong token."
    assert_empty jobs
  end

  def resetting_server(error)
    server = Class.new { define_method(:accept) { |*| raise error } }.new
    server.singleton_class.prepend(ReviewDesk::Desk::QuietResets)
    server
  end

  def test_quiet_resets_swallows_a_peer_reset
    assert_nil resetting_server(Errno::ECONNRESET).accept(:peer, :address)
  end

  def test_quiet_resets_still_raises_other_errors
    assert_raises(ArgumentError) { resetting_server(ArgumentError).accept(:peer, :address) }
  end

  def test_html_page_has_header_and_escaped_pr_button
    page = quiet_desk.send(:html_page, "Starting <x>", "https://github.com/a/b/pull/1?x=1&y=2")

    assert_includes page, "<h1>Review Desk</h1>"
    assert_includes page, "<p>Starting &lt;x&gt;</p>"
    assert_includes page, %(<a class="button" href="https://github.com/a/b/pull/1?x=1&amp;y=2">Open the PR</a>)
  end

  def test_html_page_without_url_has_no_button
    refute_includes quiet_desk.send(:html_page, "Done.", nil), %(class="button")
  end

  def test_html_page_declares_an_empty_icon
    assert_includes quiet_desk.send(:html_page, "Done.", nil), %(<link rel="icon" href="data:,">)
  end

  def test_rack_app_unknown_path_is_not_found
    status, _, body = quiet_desk.send(:rack_app, TOKEN, ->(_job) {}).call(rack_env("/nope", "t=#{TOKEN}"))

    assert_equal 404, status
    assert_includes body.join, "Unknown path."
  end

  def test_rack_app_ack_route_answers_at_once_and_hands_off_its_work
    jobs = []
    status, _, body = quiet_desk.send(:rack_app, TOKEN, jobs.method(:push)).call(rack_env("/refresh", "t=#{TOKEN}"))

    assert_equal 200, status
    assert_includes body.join, "Refreshing from GitHub; the dashboard updates in a few seconds."
    assert_equal 1, jobs.size
    assert_respond_to jobs.first, :call
  end

  LISTENER = { "port" => 47_321, "token" => TOKEN }.freeze

  def link(path)
    "http://127.0.0.1:47321#{path}?t=#{TOKEN}"
  end

  def filter_entries
    [
      entry("queued", number: 1, bot: true, created_at: "2026-10-29T12:00:00Z"),
      entry("queued", number: 2, bot: false, created_at: "2026-10-01T12:00:00Z"),
      entry("no-checkout", number: 3, bot: true, created_at: "2026-10-01T12:00:00Z"),
      entry("queued", number: 4, bot: false, created_at: "2026-10-29T12:00:00Z"),
    ]
  end

  def test_filter_line_with_listener_links_unset_choices
    line = ReviewDesk::Dashboard.filter_line(filter_entries, { "show_bots" => false, "max_age_days" => 7 }, NOW,
                                             LISTENER)

    assert_equal "Hidden: 3 (2 bot PRs · 2 older than 7d; a PR matching both counts once) — " \
                 "[refresh now](#{link("/refresh")}) · bots: [show](#{link("/bots/on")}) / **hidden** · " \
                 "age: **7d** · [30d](#{link("/max-age/30")}) · [all](#{link("/max-age/off")})", line
  end

  def test_filter_line_with_listener_bolds_bots_shown_and_all_ages
    line = ReviewDesk::Dashboard.filter_line(filter_entries, NO_FILTERS, NOW, LISTENER)

    assert_equal "Hidden: none — [refresh now](#{link("/refresh")}) · " \
                 "bots: **shown** / [hide](#{link("/bots/off")}) · " \
                 "age: [7d](#{link("/max-age/7")}) · [30d](#{link("/max-age/30")}) · **all**", line
  end

  def test_filter_line_with_listener_shows_custom_max_age_in_order
    line = ReviewDesk::Dashboard.filter_line(filter_entries, { "show_bots" => true, "max_age_days" => 14 }, NOW,
                                             LISTENER)

    assert line.end_with?("age: [7d](#{link("/max-age/7")}) · **14d** · [30d](#{link("/max-age/30")}) · " \
                          "[all](#{link("/max-age/off")})"), line
  end

  def test_filter_line_without_listener_shows_commands
    line = ReviewDesk::Dashboard.filter_line(filter_entries, { "show_bots" => false, "max_age_days" => 7 }, NOW, nil)

    assert_equal "Hidden: 3 (2 bot PRs · 2 older than 7d; a PR matching both counts once) — " \
                 "show: `review-desk.rb bots on` · `review-desk.rb max-age off`", line
  end

  def test_filter_line_without_listener_offers_hiding_shown_bots
    assert_equal "Hidden: none — hide: `review-desk.rb bots off`",
                 ReviewDesk::Dashboard.filter_line(filter_entries, NO_FILTERS, NOW, nil)
  end

  def dashboard_desk(listener)
    ReviewDesk::Desk.new(username: "rwc9u").tap { |desk| desk.instance_variable_set(:@listener_info, listener) }
  end

  def row(state)
    entry(state, repo: "Kajabi/repo", number: 1)
  end

  def test_queued_row_with_listener_links_dismiss
    cell = dashboard_desk(LISTENER).send(:extra_cell, row("queued"), :start)

    assert_equal "[start](#{link("/start/Kajabi/repo/1")}) · [dismiss](#{link("/dismiss/Kajabi/repo/1")})", cell
  end

  def test_queued_row_without_listener_has_no_dismiss
    refute_includes dashboard_desk(nil).send(:extra_cell, row("queued"), :start), "dismiss"
  end

  def test_verdict_ready_row_with_listener_links_dismiss
    cell = dashboard_desk(LISTENER).send(:extra_cell, row("verdict-ready"), :verdict)

    assert cell.end_with?(" · [dismiss](#{link("/dismiss/Kajabi/repo/1")})"), cell
  end

  def test_verdict_ready_row_without_listener_has_no_dismiss
    refute_includes dashboard_desk(nil).send(:extra_cell, row("verdict-ready"), :verdict), "dismiss"
  end

  def test_dismissed_outcome_with_listener_links_undo
    assert_equal "dismissed · [undo](#{link("/undismiss/Kajabi/repo/1")})",
                 dashboard_desk(LISTENER).send(:extra_cell, row("dismissed"), :outcome)
  end

  def test_dismissed_outcome_without_listener_is_plain
    assert_equal "dismissed", dashboard_desk(nil).send(:extra_cell, row("dismissed"), :outcome)
  end
end
