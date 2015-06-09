# vi: ts=4 expandtab

from cloudinit import handlers
from cloudinit import log as logging
from cloudinit import util

from cloudinit.settings import (PER_ALWAYS)

LOG = logging.getLogger(__name__)

TAUPAGE_AMI_CONFIG_PREFIX = "#taupage-ami-config"
TAUPAGE_AMI_CONFIG_MIME_TYPE = handlers.type_from_starts_with(TAUPAGE_AMI_CONFIG_PREFIX)

TAUPAGE_CONFIG = "/etc/taupage.yaml"


class ZalandoAMIConfigPartHandler(handlers.Handler):
    def __init__(self, paths, **_kwargs):
        handlers.Handler.__init__(self, PER_ALWAYS)

    def list_types(self):
        return [TAUPAGE_AMI_CONFIG_MIME_TYPE]

    def handle_part(self, _data, ctype, filename, payload, frequency):
        if ctype == TAUPAGE_AMI_CONFIG_MIME_TYPE:
            LOG.info("Got Taupage AMI configuration; merging with {config}".format(config=TAUPAGE_CONFIG))

            LOG.debug("Parsing given input...")
            config_new = util.load_yaml(payload)

            LOG.debug("Loading existing configuration...")
            config_yaml = util.read_file_or_url(TAUPAGE_CONFIG)
            config_old = util.load_yaml(config_yaml)

            LOG.debug("Merging configurations...")
            config_merged = dict(config_old.items() + config_new.items())

            LOG.debug("Storing merged configuration...")
            config_yaml = util.yaml_dumps(config_merged)
            util.write_file(TAUPAGE_CONFIG, config_yaml, 0o444)
