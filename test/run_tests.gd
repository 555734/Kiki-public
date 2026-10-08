extends Node
## The logic half of verification.
##
## Runs as a scene, not via --script, because GDScript only resolves autoload
## names once the autoloads exist. Integration cases drive a real instance of
## main.tscn so they exercise the same code path the players do.
##
## The tests themselves are in test/logic/, one suite per part of the game.
## This runs them in a single, fixed order -- some read what an earlier one
## left behind (the booted game, the runner's measured reach) -- and prints
## one tally.
##
## Run:  godot --headless --path . res://test/run_tests.tscn

const LogicRun = preload("res://test/logic/logic_run.gd")

var run := LogicRun.new()
var stage: Node = null
var movement: Node = null
var guardian: Node = null
var controls: Node = null
var network: Node = null

func _ready() -> void:
	stage = _suite("stage")
	movement = _suite("movement")
	guardian = _suite("guardian")
	controls = _suite("controls")
	network = _suite("network")
	await _run_all()
	print("\n--- %d checks, %d failed ---" % [run.checks, run.failures.size()])
	for f in run.failures:
		print("  FAIL  ", f)
	if run.failures.is_empty():
		print("  all logic tests passed")
	get_tree().quit(0 if run.failures.is_empty() else 1)

func _suite(domain: String) -> Node:
	var suite: Node = load("res://test/logic/%s_tests.gd" % domain).new()
	suite.name = domain.capitalize() + "Tests"
	suite.run = run
	add_child(suite)
	return suite

func _run_all() -> void:
	network._test_eos_contracts()
	await network._test_the_link_records_what_happened()
	await network._test_an_unmeasured_round_trip_says_so()
	await network._test_a_link_that_never_opened_keeps_trying()
	await network._test_a_new_room_ends_the_old_one()
	await network._test_the_guest_clock_keeps_running()
	await network._test_the_aim_stream_is_rationed()
	await network._test_a_refused_handshake_is_visible()
	await network._test_the_diagnostic_reports_every_step()
	await controls._test_device_ownership()
	await network._test_three_names_for_who()
	network._test_settings_survive_each_other()
	stage._test_assets()
	stage._test_walker_skins()
	stage._test_stage_rules_reach_gimmicks()
	stage._test_every_stage_keeps_the_contract()
	await guardian._test_gauge_rules()
	await guardian._test_platform_limits()
	await guardian._test_wall_limits()
	await guardian._test_one_press_tools()
	await guardian._test_a_tap_puts_it_where_you_pointed()
	await guardian._test_shot_drag_keeps_the_view()
	await guardian._test_sniper()
	await guardian._test_aiming_at_an_enemy_kills_it()
	await guardian._test_the_rifle_helps_you_aim()
	await movement._test_runner_arc()
	await movement._test_double_jump()
	await movement._test_updraft_after_tapped_jump()
	await movement._test_four_ways_to_change_direction()
	await movement._test_dash()
	await movement._test_top_gear()
	await movement._test_stomp_and_damage()
	await guardian._test_wall_blocks_projectile()
	await movement._test_checkpoint_respawn()
	stage._test_level_reachability()
	guardian._test_guardian_never_idle()
	controls._test_every_control_is_reachable_and_separate()
	controls._test_controls_can_be_resized()
	await guardian._test_the_guardian_can_look_ahead()
	await controls._test_virtual_stick()
	await stage._test_solid_decor()
	await stage._test_enemies_hold_their_ground()
	network._test_determinism()
	await network._test_rescue_under_latency()
	await network._test_rewind_never_harms()
	network._test_rewind_is_bounded()
	await network._test_loopback_link()
	network._test_bandwidth_budget()
	await network._test_host_answers_the_guardian()
	await network._test_malformed_packets_are_dropped()
	await network._test_client_shows_the_host()
	await network._test_a_dead_enemy_stays_dead_on_both_screens()
	await controls._test_connect_screen_responds_to_touch()
	stage._test_everything_stands_on_the_ground()
	await stage._test_the_game_has_a_voice()
	await movement._test_two_hits_end_the_run()
	await stage._test_pickups_and_pads()
	await movement._test_the_catch_is_graded()
	await stage._test_warp_pair()
	await network._test_warp_over_the_wire()
	await network._test_a_dropped_link_comes_back()
	await network._test_a_slow_start_is_not_a_drop()
	await network._test_reconnecting_twice_changes_nothing()
	await guardian._test_shooting_the_trigger_launches_the_runner()
	await guardian._test_a_platform_is_still_a_platform()
	await guardian._test_the_guardian_wall_can_be_kicked_off()
	await guardian._test_the_shieldbearer_needs_both_of_them()
	await guardian._test_a_crystal_pays_the_guardian_once()
	await movement._test_the_runner_can_catch_an_edge()
	await guardian._test_the_guardian_can_take_one_back()
	await guardian._test_either_of_them_can_point()
	await controls._test_only_a_tap_counts_as_a_tap()
	await controls._test_the_finger_decides_where_it_landed()
	await controls._test_an_interruption_lets_go_of_everything()
	await controls._test_two_thumbs_do_not_interfere()
	await movement._test_auto_dash_is_a_real_choice()
	await network._test_two_taps_make_one_session()
	network._test_a_shared_report_hides_who_it_is()
