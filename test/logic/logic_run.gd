extends RefCounted
## One run of the logic suites: the tally they all add to and the state that
## passes from one suite's test to another's.

var checks: int = 0
var failures: Array[String] = []
var main: Node2D = null
var reach: Dictionary = {}
