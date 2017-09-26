#
# The MIT License (MIT)
#
# Copyright (c) 2014 Jharrod LaFon
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#
import datetime
import json
import os
import time


class CallbackModule(object):
    """A plugin for timing tasks."""

    def __init__(self):
        self.stats = []
        self.start = time.time()
        self.current = None
        self.current_start = None

    def playbook_on_task_start(self, name, is_conditional):
        """Logs the start of each task."""

        if os.getenv("ANSIBLE_PROFILE_DISABLE") is not None:
            return

        if self.current_start is not None:
            # Record the running time of the last executed task
            self.stats.append((self.current, time.time() - self.current_start))

        # Record the start time of the current task
        self.current = name
        self.current_start = time.time()

    def playbook_on_stats(self, stats):
        """Prints the timings."""

        if os.getenv("ANSIBLE_PROFILE_DISABLE") is not None:
            return

        # Record the timing of the very last task
        if self.current_start is not None:
            self.stats.append((self.current, time.time() - self.current_start))

        # Sort the tasks by their running time
        results = sorted(
            self.stats,
            key=lambda value: value[1],
            reverse=True,
        )

        if os.getenv("ANSIBLE_PROFILE_DUMP_JSON"):
            date_string = datetime.datetime.utcnow().strftime('%Y%m%d-%H%M%S')
            file_name = 'playbook-profile-%s.json' % date_string
            with open(file_name, 'w') as outfile:
                json.dump(results, outfile)

        if os.getenv("ANSIBLE_PROFILE_SHOW_ALL") is None:
            # Just keep the top 10
            results = results[:10]

        # Print the timings
        for name, elapsed in results:
            print(
                "{0:-<70}{1:->9}".format(
                    '{0} '.format(name),
                    ' {0:.02f}s'.format(elapsed),
                )
            )
        print("{0:-<79}".format("-"))
        print("{0:-<70}{1:->9}".format(
            '{0} '.format("Total:"),
            ' {0:.02f}s'.format(time.time() - self.start),
        ))
