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

  def test_reviewing_with_verdict_file_is_verdict_ready
    assert_equal "verdict-ready", Transition.call(entry("reviewing"), facts, verdict_ready: true)
  end

  def test_reviewing_without_verdict_file_stays_reviewing
    assert_equal "reviewing", Transition.call(entry("reviewing"), facts)
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

  def test_verdict_ready_survives_withdrawn_request
    assert_equal "verdict-ready", Transition.call(entry("verdict-ready"), facts(requested: false))
  end

  def test_closed_pr_is_dropped
    assert_equal "dropped", Transition.call(entry("queued"), facts(open: false))
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

  TOKEN = "a1b2c3d4"

  def test_start_path_with_token_routes_to_pr_key
    route = ReviewDesk::Http.route("GET /start/Kajabi/kajabi-products/60090?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)

    assert_equal [:start, "Kajabi/kajabi-products#60090"], route
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

  def test_malformed_start_path_is_not_found
    assert_equal [:not_found], ReviewDesk::Http.route("GET /start/Kajabi/repo/abc?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_non_get_request_is_bad_request
    assert_equal [:bad_request], ReviewDesk::Http.route("POST /start-all?t=#{TOKEN} HTTP/1.1\r\n", TOKEN)
  end

  def test_garbage_request_line_is_bad_request
    assert_equal [:bad_request], ReviewDesk::Http.route("\x16\x03\x01", TOKEN)
  end
end
