#!/usr/bin/env python3

import logging
import sys
import os
import taupage
import subprocess
import re
from contextlib import contextmanager
import tempfile

RSYSLOG_CONF = "/etc/rsyslog.conf"
APPLICATION_LOG_TEMPLATE="""
$outchannel docker_application_log,/var/log/application.log,{max_size},/usr/local/sbin/_logrotate
:syslogtag, startswith, "docker" :omfile:$docker_application_log\n
& ~
"""

@contextmanager
def atomically_replace(path):
    tempfile = os.path.join(os.path.dirname(path), ".{}-tmp".format(os.path.basename(path)))
    with open(tempfile, "w") as f:
        yield f
    os.rename(tempfile, path)

def parse_application_log_hardlimit(config):
    hardlimit = config.get("rsyslog_application_hardlimit")
    if hardlimit is not None:
        try:
            units = {"k": 1024**1,
                     "m": 1024**2,
                     "g": 1024**3}

            hardlimit = hardlimit.strip().lower()
            for unit, multiplier in units.items():
                if hardlimit.endswith(unit):
                    return int(hardlimit[:-1]) * multiplier

            return int(hardlimit)
        except ValueError as e:
            logging.error("Invalid configuration for rsyslog_application_hardlimit")
            logging.exception(e)

def apply_max_message_size(max_message_size):
    if max_message_size is not None:
        with atomically_replace(RSYSLOG_CONF) as f:
            config = open(RSYSLOG_CONF).read()
            f.write(config)
            f.write("\n")
            if "$MaxMessageSize" not in config:
                logging.info("Configuring rsyslog max message size: {}".format(max_message_size))
                f.write("$MaxMessageSize {}\n".format(max_message_size))

def apply_application_log_hardlimit(hardlimit):
    if hardlimit is not None:
        logging.info("Configuring rsyslogd to forcibly rotate application.log after a hard limit of {} bytes".format(hardlimit))
        with atomically_replace("/etc/rsyslog.d/24-application.conf") as f:
            f.write(APPLICATION_LOG_TEMPLATE.format(max_size=hardlimit))
            f.write("\n")

        logging.info("Reconfiguring rsyslog to not drop privileges so it'd be able to invoke logrotate")
        with atomically_replace(RSYSLOG_CONF) as f:
            with open(RSYSLOG_CONF) as old_config:
                f.writelines((line for line in old_config if "$PrivDrop" not in line))
                f.write("\n")

def main():
    taupage.configure_logging()
    config = taupage.get_config()

    max_message_size = config.get("rsyslog_max_message_size")
    application_log_hardlimit = parse_application_log_hardlimit(config)

    apply_max_message_size(max_message_size)
    apply_application_log_hardlimit(application_log_hardlimit)

    if max_message_size is not None or application_log_hardlimit is not None:
        logging.info("Restarting rsyslogd to apply configuration changes...")
        subprocess.check_call(["service", "rsyslog", "restart"])

if __name__ == '__main__':
    main()
