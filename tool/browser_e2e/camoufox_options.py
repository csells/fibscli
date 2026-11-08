"""Prepare private, compatible browser launch options for computer UI tests."""
import argparse
import json
import os

from camoufox import DefaultAddons
from camoufox.utils import launch_options

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
args = parser.parse_args()
options = launch_options(
    browser='official/156.0.1-beta.36',
    headless=True,
    os='macos',
    locale='en-US',
    humanize=True,
    exclude_addons=[DefaultAddons.UBO],
    main_world_eval=True,
)
names = {'executable_path': 'executablePath', 'firefox_user_prefs': 'firefoxUserPrefs'}
options = {names.get(key, key): value for key, value in options.items()}
fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as stream:
    json.dump(options, stream)
print('Prepared Camoufox156.0.1-beta.36 browser options.')
