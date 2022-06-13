import configparser
from domino import Domino
# import joblib
import os
import sys
import time
import pprint
import logging
"""
on each tick:
- iterate through list of tasks and check status of dependencies.
- return a list of tasks that are elibible to be submitted.
- submit eligible runs
- how to detect when pipeline is in a failed state? how to handle partial pipeline failure?
"""
logging.getLogger("urllib3").setLevel(logging.WARNING)
logging.getLogger("requests").setLevel(logging.WARNING)
PROJECT_OWNER = os.environ["DOMINO_PROJECT_OWNER"]
PROJECT_NAME = os.environ["DOMINO_PROJECT_NAME"]
domino_api = Domino(PROJECT_OWNER + "/" + PROJECT_NAME)
class DominoRun:
    """
    self.task_id        # name of task
    self.command        # command to submit to API
    self.isDirect       # isDirect flag to submit to API
    self.max_retries    # maximum retries
    self.run_id         # ID of latest run attempt
    self.retries        # number of retries so far
    self.status()       # check API for status - stop checking once Succeeded or (Error/Failed and self.retries < self.max_retries)
    self._status        # last .status()
    once submitted, it polls status, and retries (submits re-runs) up to max_retries
    """
    def __init__(self, task_id, command, max_retries=0, tier=None, environment=None):
        self.task_id = task_id
        self.command = command
        # self.isDirect = isDirect
        self.max_retries = max_retries
        self.tier = tier
        self.environment = environment
        self.run_id = None
        self.retries = 0
        self._status = "Unsubmitted"
    def status(self):
        if self._status not in ("Succeeded", "Unsubmitted", "Error", "Failed"):
            api_status = domino_api.runs_status(self.run_id)["status"] # needs error handling?
            self.set_status(api_status)
        return self._status
    def set_status(self, status):
        self._status = status
    def is_complete(self):
        return self.status() == "Succeeded"
    # should submission and retry logic be part of DominoRun object, or the PipelineRunner?
class Dag:
    """
    self.tasks              # dictionary of task_ids -> DominoRun objects
    self.dependency_graph   # dictionary of task_ids -> list of dependency task_ids
    """
    def __init__(self, tasks, dependency_graph, allow_partial_failure=False):
        self.tasks = tasks
        self.dependency_graph = dependency_graph
        self.allow_partial_failure = allow_partial_failure
    def get_dependency_statuses(self, task_id):
        dependency_statuses = []
        deps = self.dependency_graph[task_id]
        for dep in deps:
            dependency_statuses += [self.tasks[dep].status()]
        return dependency_statuses
    def are_task_dependencies_complete(self, task_id):
        dependency_statuses = self.get_dependency_statuses(task_id)
        if dependency_statuses:
            all_deps_succeeded = all(status == 'Succeeded' for status in dependency_statuses)
        else:
            all_deps_succeeded = True
        return all_deps_succeeded
    def get_ready_tasks(self):
        ready_tasks = []
        for task_id, task in self.tasks.items():
            deps_complete = self.are_task_dependencies_complete(task_id)
            task_status_ready = (task.status() in ("Error", "Failed") and task.retries < task.max_retries) or task.status() == 'Unsubmitted'
            if deps_complete and task_status_ready:
                ready_tasks.append(task)
        return ready_tasks
    def get_failed_tasks(self):
        failed_tasks = []
        for task_id, task in self.tasks.items():
            if task.status() in ('Error', 'Failed') and task.retries >= task.max_retries:
                failed_tasks.append(task)
        return failed_tasks
    def pipeline_status(self):
        status = 'Running'
        if len(self.get_failed_tasks()) > 0 and self.allow_partial_failure == False:
            status = 'Failed'
        elif all(task.is_complete() for task_id, task in self.tasks.items()):
            status = 'Succeeded'
#         elif len(self.get_ready_tasks()) == 0: # infinite loop if not Succeeded
#             status = 'Failed'
        return status
        # inspect graph, run statuses, allow_partial_failure to determine whether pipeline should continue
    def validate_dag(self):
        pass
    def validate_run_command(self):
        pass
    def __str__(self):
        return pprint.pformat(self.dependency_graph, width=1)
def build_dag(cfg_file_path):
    c = configparser.ConfigParser(allow_no_value=True)
    c.read(cfg_file_path)
    tasks = {}
    dependency_graph = {}
    task_ids = c.sections()
    for task_id in task_ids:
        if c.has_option(task_id, "depends"):
            dependencies_str = c.get(task_id, "depends") # default?
            dependencies = dependencies_str.split()
        else:
            dependencies = []
        dependency_graph[task_id] = dependencies
        # if c.has_option(task_id, "direct"):
        #     isDirect = c.get(task_id, "direct").lower() == "true"
        # else:
        #     isDirect = False
        command_str = c.get(task_id, "command")
        # if isDirect:
        command = str(command_str)
        # else:
        #     command = command_str.split()
        domino_run_kwargs = {}
        if c.has_option(task_id, "max_retries"):
            max_retries = c.get(task_id, "max_retries")
            domino_run_kwargs["max_retries"] = max_retries
        if c.has_option(task_id, "tier"):
            tier = c.get(task_id, "tier")
            domino_run_kwargs["tier"] = tier
        # Set the desired compute environment
        if c.has_option(task_id, "environment"):
            environment = c.get(task_id, "environment")
            domino_run_kwargs["environment"] = environment
        tasks[task_id] = DominoRun(task_id, command, **domino_run_kwargs)
    return Dag(tasks, dependency_graph)
class PipelineRunner:
    '''
    should this be stateless or stateful?
    - needs to be stateful to track run IDs and states (for retry logic) of various tasks
    - use Dag object to store state
    '''
    def __init__(self, dag, tick_freq=15):
        self.dag = dag
        self.tick_freq = tick_freq
    def run(self):
        while True:
            if self.dag.pipeline_status() == 'Succeeded':
                print("Pipeline Succeeded")
                break
            elif self.dag.pipeline_status() == 'Failed':
                raise Exception("Pipeline Execution Failed")
            ready_tasks = dag.get_ready_tasks()
            print("Ready tasks: {0}".format(", ".join([task.task_id for task in ready_tasks])))
            for task in ready_tasks:
                self.submit_task(task)
            time.sleep(self.tick_freq)
    def submit_task(self, task):
        print("## Submitting task ##\ntask_id: {0}\ncommand: {1}\ntier override: {2}\nenvironment override: {3}".format(task.task_id, task.command, task.tier, task.environment))
        if task.tier:
            # response_json = domino_api.runs_start(task.command, isDirect=task.isDirect, tier=task.tier)
            if task.environment:
                response_json = domino_api.job_start(task.command, hardware_tier_name=task.tier, environment_id=task.environment)
            else:
                response_json = domino_api.job_start(task.command, hardware_tier_name=task.tier)
        else:
            # response_json = domino_api.runs_start(task.command, isDirect=task.isDirect)
            if task.environment:
                response_json = domino_api.job_start(command=str(task.command), environment_id=task.environment)
                # response_json = domino_api.job_start(command, commit_id=None, hardware_tier_name=None, environment_id=None, on_demand_spark_cluster_properties=None)
            else:
                response_json = domino_api.job_start(task.command)
        print(response_json)
        print("## Submitted task: {0} ##".format(task.task_id))
        # error handling?
        task.run_id = response_json["id"]
        task.set_status("Submitted") # will technically be Queued or something else, but this will update on the next status check
"""
v0.1: just read the cfg file and submit commands. skip all validation, put responsibility on end-user. assume jobs are idempotent.
"""
if __name__ == '__main__':
    # pipeline_cfg_path = sys.argv[1]
    pipeline_cfg_path = "jobs.cfg"
    dag = build_dag(pipeline_cfg_path)
    print(dag)
    pipeline_runner = PipelineRunner(dag)
    pipeline_runner.run()
