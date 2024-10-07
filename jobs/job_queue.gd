extends Node2D
class_name JobQueue

const BID_TIMEOUT = 1.0

var job_queue = []

class JobBid:
	var ant = null
	var bid = 0.0

class Job:
	var type = null
	var target = null
	var issuer = null # the chamber that created the job
	var _bids = []
	var _bid_timeout = BID_TIMEOUT

func add_job(job: Job) -> void:
	job._bids = []
	job._bid_timeout = BID_TIMEOUT
	job_queue.append(job)
	if job.target and is_instance_valid(job.target):
		if not job.target.is_connected("tree_exited", Callable(self, "_remove_job").bind(job)):
			job.target.connect("tree_exited", Callable(self, "_remove_job").bind(job))
	get_tree().create_timer(BID_TIMEOUT).connect("timeout", Callable(self, "_bid_timeout").bind(job))

func bid_for_job(job: Job, ant: WorkerAnt, bid: float) -> void:
	var job_bid = JobBid.new()
	job_bid.ant = ant
	job_bid.bid = bid
	job._bids.append(job_bid)

func _bid_timeout(job: Job) -> void:
	# check if job still exists
	if job_queue.find(job) == -1:
		return

	var best_bid = INF
	var best_ant = null
	for job_bid in job._bids:
		if job_bid.bid <= best_bid:
			best_bid = job_bid.bid
			best_ant = job_bid.ant

	if best_ant != null:
		job_queue.remove_at(job_queue.find(job))
		best_ant.award_job(job)
	else:
		# print("No ants bid for job in time. Rescheduling job")
		job_queue.remove_at(job_queue.find(job))
		add_job(job)

func _remove_job(job: Job) -> void:
	print("Job removed %s" % job)
	job_queue.remove_at(job_queue.find(job))

func peek_next_job() -> Job:
	if job_queue.size() > 0:
		return job_queue[0]
	else:
		return null

func has_jobs() -> bool:
	return not job_queue.is_empty()

func clear_jobs() -> void:
	job_queue.clear()
