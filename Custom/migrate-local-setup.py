#!/usr/bin/env python3
"""Copy prebuilt extension payloads and filtered preferences between isolated app roots."""
import argparse
import collections
import hashlib
import json
import os
import plistlib
import subprocess
import uuid
from urllib.parse import urlsplit
from pathlib import Path
import re
import shutil
import tempfile

CREDENTIAL = re.compile(r'password|passwd|secret|token|credential|authorization|authentication|api[\W_]*key|private[\W_]*key|access[\W_]*key|client[\W_]*key|bearer', re.I)
TOKEN = re.compile(r'^(?:sk-|gh[pousr]_|github_pat_|AIza|AKIA|ASIA)|^eyJ[\w-]+\.[\w-]+\.[\w-]+$|^(?:Bearer|Basic)\s', re.I)

def safe_name(name):
    return name.replace('/', '-').replace('@', '')

def raw_value(raw):
    if not isinstance(raw, dict) or len(raw) != 1:
        raise ValueError('unsupported preference encoding')
    kind, wrapped = next(iter(raw.items()))
    if kind not in {'string', 'number', 'bool'} or not isinstance(wrapped, dict) or set(wrapped) != {'_0'}:
        raise ValueError('unsupported preference encoding')
    return kind, wrapped['_0']

def secret_like(value):
    if not isinstance(value, str):
        return False
    if TOKEN.search(value.strip()):
        return True
    # Long opaque identifiers deserve manual entry, even when a schema calls them plain text.
    return bool(re.fullmatch(r'[A-Za-z0-9_+=-]{24,}', value.strip()))

def digest_tree(root):
    result = {}
    for file in sorted(root.rglob('*')):
        if file.is_symlink():
            raise ValueError('symlink in extension payload')
        if file.is_file():
            result[str(file.relative_to(root))] = (hashlib.sha256(file.read_bytes()).hexdigest(), file.stat().st_mode & 0o777)
    return result


def decoded_json(value):
    return json.loads(value) if isinstance(value, (bytes, str)) else value

def encoded_json(value):
    return json.dumps(value, separators=(',', ':')).encode()

def safe_text(value):
    return isinstance(value, str) and not TOKEN.search(value.strip()) and not secret_like(value)

def valid_model_list(value):
    return isinstance(value, list) and all(isinstance(item, str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:/@+-]{0,255}', item) and not TOKEN.search(item) for item in value)

def valid_binding(binding):
    if not isinstance(binding, dict) or len(binding) != 1:
        return False
    kind, value = next(iter(binding.items()))
    if kind in {'globe', 'doubleGlobe'}:
        return value == {}
    if not isinstance(value, dict) or set(value) != {'_0'}:
        return False
    wrapped = value['_0']
    if kind == 'doubleTap':
        return wrapped in {'control', 'option', 'shift', 'command'}
    if kind == 'combo':
        return isinstance(wrapped, dict) and set(wrapped) == {'carbonKeyCode', 'carbonModifiers'} and type(wrapped['carbonKeyCode']) is int and 0 <= wrapped['carbonKeyCode'] < 256 and type(wrapped['carbonModifiers']) is int and wrapped['carbonModifiers'] >= 0
    return False

def preference_plan(args, counts):
    source_plist = Path.home() / 'Library' / 'Preferences' / (args.source_domain + '.plist')
    source = plistlib.loads(source_plist.read_bytes())
    delta = {}
    retained = []
    known_connection_fields = {'id', 'name', 'provider', 'baseURL', 'models', 'visionModels', 'reasoningOptions'}
    if 'aiConnections' in source:
        for connection in decoded_json(source['aiConnections']):
            try:
                if not isinstance(connection, dict) or set(connection) - known_connection_fields:
                    raise ValueError('unknown connection schema')
                uuid.UUID(connection['id'])
                if connection['provider'] not in {'openAI', 'anthropic', 'gemini', 'openRouter', 'openAICompatible'}:
                    raise ValueError('unknown provider')
                if not safe_text(connection['name']):
                    raise ValueError('unsafe name')
                url = urlsplit(connection['baseURL'])
                if url.scheme not in {'https', 'http'} or not url.hostname or url.username or url.password or url.query or url.fragment:
                    raise ValueError('endpoint carries credentials or unknown routing')
                if url.scheme == 'http' and url.hostname not in {'localhost', '127.0.0.1', '::1'}:
                    raise ValueError('insecure endpoint')
                if any(secret_like(segment) or TOKEN.search(segment) for segment in url.path.split('/')):
                    raise ValueError('opaque endpoint path')
                if not valid_model_list(connection['models']) or not valid_model_list(connection.get('visionModels', [])):
                    raise ValueError('invalid models')
                for model, options in (connection.get('reasoningOptions') or {}).items():
                    if not safe_text(model) or set(options) - {'efforts', 'defaultEffort'} or not valid_model_list(options['efforts']):
                        raise ValueError('unknown reasoning metadata')
                    if options.get('defaultEffort') is not None and not safe_text(options['defaultEffort']):
                        raise ValueError('invalid reasoning choice')
                retained.append(connection)
            except (ValueError, TypeError, KeyError) as error:
                counts['ai_connections_excluded'] += 1
                known_reasons = {'unknown connection schema', 'unknown provider', 'unsafe name', 'endpoint carries credentials or unknown routing', 'insecure endpoint', 'opaque endpoint path', 'invalid models', 'unknown reasoning metadata', 'invalid reasoning choice'}
                if str(error) in known_reasons:
                    counts['ai_connection_exclusion_' + str(error).replace(' ', '_')] += 1
        if retained:
            delta['aiConnections'] = encoded_json(retained)
            counts['ai_connections_copied'] = len(retained)
            counts['ai_connection_models_copied'] = sum(len(x['models']) for x in retained)
    if 'aiDefaultModel' in source:
        selection = decoded_json(source['aiDefaultModel'])
        valid = isinstance(selection, dict) and len(selection) == 1
        if valid:
            route, options = next(iter(selection.items()))
            valid = route in {'appleIntelligence', 'codex', 'chatGPT', 'claude', 'grok', 'openCode', 'cursor', 'api'} and isinstance(options, dict)
            if valid and route == 'appleIntelligence':
                valid = not options
            elif valid:
                valid = set(options) <= ({'model', 'effort', 'connection'} if route == 'api' else {'model', 'effort'}) and valid_model_list([options.get('model')])
                valid = valid and (options.get('effort') is None or safe_text(options['effort']))
                if valid and route == 'api':
                    valid = any(x['id'].lower() == str(options.get('connection', '')).lower() and options['model'] in x['models'] for x in retained)
        if valid:
            delta['aiDefaultModel'] = encoded_json(selection)
            counts['ai_default_model_copied'] = 1
        else:
            counts['ai_default_model_excluded'] = 1
    enum_settings = {
        'aiRetentionDays': {-1, 7, 30, 90}, 'aiOpensTo': {0, 1},
        'aiNewChatAfterMinutes': {-1, 2, 5, 10, 30}, 'aiToolRounds': {-1, 10, 25, 50, 100}
    }
    for key, choices in enum_settings.items():
        if key in source and type(source[key]) is int and source[key] in choices:
            delta[key] = source[key]
    if isinstance(source.get('aiShownModels'), dict) and all(isinstance(k, str) and valid_model_list(v) for k, v in source['aiShownModels'].items()):
        delta['aiShownModels'] = source['aiShownModels']
    if valid_model_list(source.get('aiDisabledRoutes')):
        # Disabled routes only narrow permission and never enable an installed tool.
        delta['aiDisabledRoutes'] = source['aiDisabledRoutes']
    for key in ['aiEnabled', 'aiInstalledProviders', 'aiWebSearch', 'snippetsEnabled', 'extensionsEnabled', 'calendarEnabled', 'autoJoinMeetings', 'cameraPreview', 'quickActionsEnabled', 'mcpEnabled']:
        if key in source:
            counts['consent_fields_excluded'] += 1
    installed_refs = set()
    for manifest_file in (args.destination.expanduser() / 'extensions').glob('*/package.json'):
        manifest = json.loads(manifest_file.read_text())
        installed_refs.update('extension:' + manifest['name'] + '/' + x['name'] for x in manifest.get('commands', []))
    bound = []
    for key, value in source.items():
        prefix = 'hotkey.extensionCommand.'
        if not key.startswith(prefix):
            continue
        reference = key[len(prefix):]
        binding = decoded_json(value)
        # This utility deliberately leaves unfamiliar binding schemas for native UI entry.
        if reference not in installed_refs or not valid_binding(binding):
            counts['extension_hotkeys_excluded'] += 1
            continue
        delta[key] = value
        bound.append(reference)
    if bound:
        delta['boundExtensionCommandEntryIDs'] = sorted(bound)
        counts['extension_hotkeys_copied'] = len(bound)
    aliases = source.get('launcherAliases')
    if isinstance(aliases, dict):
        destination_plist = Path.home() / 'Library' / 'Preferences' / (args.destination_domain + '.plist')
        current = plistlib.loads(destination_plist.read_bytes()) if destination_plist.exists() else {}
        merged = dict(current.get('launcherAliases', {}))
        for key, alias in aliases.items():
            if key in installed_refs and safe_text(alias):
                merged[key] = alias
                counts['extension_aliases_copied'] += 1
        if counts['extension_aliases_copied']:
            delta['launcherAliases'] = merged
    counts['configuration_fields_copied'] = len(delta)
    return delta

def apply_preferences(args, delta, backup, counts):
    target = Path.home() / 'Library' / 'Preferences' / (args.destination_domain + '.plist')
    current = plistlib.loads(target.read_bytes()) if target.exists() else {}
    saved = {key: current[key] for key in delta if key in current}
    absent = sorted(set(delta) - set(current))
    rollback = backup / 'preferences-before.plist'
    rollback.write_bytes(plistlib.dumps(saved))
    rollback.chmod(0o600)
    (backup / 'preferences-originally-absent.json').write_text(json.dumps(absent))
    delta_file = backup / 'preferences-applied.plist'
    delta_file.write_bytes(plistlib.dumps(delta))
    delta_file.chmod(0o600)
    # Foundation writes through cfprefsd, preserving every unrelated destination preference.
    swift = r"""
import Foundation
let args = CommandLine.arguments
let domain = args[1]
let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
let delta = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
let defaults = UserDefaults.standard
var current = defaults.persistentDomain(forName: domain) ?? [:]
for (key, value) in delta { current[key] = value }
defaults.setPersistentDomain(current, forName: domain)
guard defaults.synchronize(), let verified = defaults.persistentDomain(forName: domain) else { exit(2) }
for (key, value) in delta {
    guard let found = verified[key], NSDictionary(dictionary: [key: found]).isEqual(to: [key: value]) else { exit(3) }
}
"""
    result = subprocess.run(['/usr/bin/swift', '-module-cache-path', str(backup / 'swift-module-cache'), '-e', swift, args.destination_domain, str(delta_file.resolve())], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError('preference domain write failed')
    counts['configuration_fields_verified'] = len(delta)

def run(args):
    source = args.source.expanduser().resolve()
    destination = args.destination.expanduser().resolve()
    backup = args.backup_dir.expanduser().resolve()
    if source == destination or source in destination.parents or destination in source.parents:
        raise ValueError('source and destination must be independent')
    if not all(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]+', domain) for domain in [args.source_domain, args.destination_domain]):
        raise ValueError('invalid preference domain')
    if destination.name != args.destination_domain or source.name != args.source_domain:
        raise ValueError('storage root must match its preference domain')
    staging_root = args.staging_dir.expanduser().resolve()
    if any(folder == root or root in folder.parents for folder in [backup, staging_root] for root in [source, destination]):
        raise ValueError('backup and staging must be outside both app storage roots')
    if args.apply:
        running_check = r'''
import AppKit
let domains = Set(CommandLine.arguments.dropFirst())
if NSWorkspace.shared.runningApplications.contains(where: { app in
    app.bundleIdentifier.map(domains.contains) ?? false
}) { exit(1) }
'''
        result = subprocess.run(['/usr/bin/swift', '-module-cache-path', str(staging_root / 'migration-module-cache'), '-e', running_check, args.source_domain, args.destination_domain], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode:
            raise RuntimeError('stop both apps before applying migration')
    if backup.exists():
        raise ValueError('backup directory must be new')
    counts = collections.Counter()
    plans = []
    with tempfile.TemporaryDirectory(prefix='extension-import-', dir=args.staging_dir) as temporary:
        staging = Path(temporary)
        for folder in ([] if args.preferences_only else sorted((source / 'extensions').iterdir())):
            if not folder.is_dir():
                continue
            manifest = json.loads((folder / 'package.json').read_text())
            name = manifest['name']
            if not isinstance(name, str) or not name or name.startswith('/') or '..' in name.split('/'):
                raise ValueError('invalid extension name')
            destination_name = name.replace('/', '-')
            if '/' in destination_name or destination_name in {'.', '..'}:
                raise ValueError('invalid extension folder name')
            commands = manifest.get('commands', [])
            built = []
            for command in commands:
                command_name = command['name']
                if '/' in command_name or command_name in {'.', '..'}:
                    raise ValueError('invalid command name')
                command_file = folder / (command_name + '.js')
                if command_file.is_file():
                    built.append(command_file)
            if not built:
                raise ValueError('extension has no built command files')
            digest_tree(folder)
            payload = staging / 'extensions' / destination_name
            payload.mkdir(parents=True)
            for file in [folder / 'package.json', *built]:
                shutil.copy2(file, payload / file.name)
            if (folder / 'assets').exists():
                shutil.copytree(folder / 'assets', payload / 'assets', copy_function=shutil.copy2)
            state_source = source / 'extension-data' / (safe_name(name) + '.json')
            state_target = None
            if state_source.exists():
                if state_source.is_symlink():
                    raise ValueError('symlink in extension state')
                state = json.loads(state_source.read_text())
                counts['state_files_seen'] += 1
                schemas = {}
                schema_items = manifest.get('preferences', []) + [schema for command in commands for schema in command.get('preferences', [])]
                for schema in schema_items:
                    key = schema.get('name')
                    if isinstance(key, str):
                        schemas[key] = schema
                kept = {}
                for key, raw in state.get('preferences', {}).items():
                    schema = schemas.get(key)
                    if not schema:
                        counts['preferences_excluded_unmatched_schema'] += 1
                        continue
                    kind = schema.get('type', 'textfield')
                    label = ' '.join(str(schema.get(field, '')) for field in ['name', 'title', 'label', 'description'])
                    if kind == 'password' or CREDENTIAL.search(label):
                        counts['preferences_excluded_credential_schema'] += 1
                        continue
                    try:
                        encoding, value = raw_value(raw)
                    except ValueError:
                        counts['preferences_excluded_unsupported_encoding'] += 1
                        continue
                    if secret_like(value):
                        counts['preferences_excluded_credential_value'] += 1
                        continue
                    if isinstance(value, str) and str(source) in value:
                        counts['preferences_excluded_official_storage_reference'] += 1
                        continue
                    if kind == 'checkbox' and encoding != 'bool':
                        counts['preferences_excluded_schema_mismatch'] += 1
                        continue
                    if kind == 'dropdown' and value not in {option.get('value') for option in schema.get('data', [])}:
                        counts['preferences_excluded_schema_mismatch'] += 1
                        continue
                    if kind not in {'textfield', 'checkbox', 'dropdown', 'file', 'directory', 'appPicker'}:
                        counts['preferences_excluded_unknown_schema_kind'] += 1
                        continue
                    kept[key] = raw
                    counts['preferences_copied'] += 1
                counts['cache_entries_excluded'] += len(state.get('caches', {}))
                counts['local_storage_entries_excluded'] += len(state.get('localStorage', {}))
                counts['accessory_entries_excluded'] += len(state.get('accessoryValues', {}))
                if kept:
                    state_target = staging / 'extension-data' / state_source.name
                    state_target.parent.mkdir(exist_ok=True)
                    state_target.write_text(json.dumps({'localStorage': {}, 'caches': {}, 'preferences': kept, 'accessoryValues': {}}, indent=2) + '\n')
                    state_target.chmod(0o600)
            plans.append((payload, state_target))
            counts['extension_payloads_copied'] += 1
            counts['command_bundles_copied'] += len(built)
        preference_delta = preference_plan(args, counts) if args.include_preferences or args.preferences_only else {}
        if not args.apply:
            print(json.dumps(dict(counts), indent=2))
            return
        backup.mkdir(parents=True)
        for payload, state in plans:
            targets = [(payload, destination / 'extensions' / payload.name)]
            if state:
                targets.append((state, destination / 'extension-data' / state.name))
            for staged, target in targets:
                if target.is_symlink():
                    raise ValueError('symlink in destination')
                if target.exists():
                    saved = backup / target.relative_to(destination)
                    saved.parent.mkdir(parents=True, exist_ok=True)
                    if target.is_dir():
                        shutil.copytree(target, saved, copy_function=shutil.copy2)
                    else:
                        shutil.copy2(target, saved)
                    counts['existing_targets_backed_up'] += 1
        # Every planned overwrite is backed up before the first destination mutation.
        for payload, state in plans:
            target = destination / 'extensions' / payload.name
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(payload, target, copy_function=shutil.copy2)
            if digest_tree(payload) != digest_tree(target):
                raise ValueError('payload verification failed')
            if state:
                target_state = destination / 'extension-data' / state.name
                target_state.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(state, target_state)
                if state.read_bytes() != target_state.read_bytes():
                    raise ValueError('preference verification failed')
                counts['preference_files_copied'] += 1
        if preference_delta:
            apply_preferences(args, preference_delta, backup, counts)
        counts['payloads_verified_bytes_and_modes'] = len(plans)
        (backup / 'migration-summary.json').write_text(json.dumps(dict(counts), indent=2) + '\n')
        print(json.dumps(dict(counts), indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--backup-dir', type=Path, required=True)
    parser.add_argument('--staging-dir', type=Path, required=True)
    parser.add_argument('--source-domain', required=True)
    parser.add_argument('--destination-domain', required=True)
    parser.add_argument('--preferences-only', action='store_true')
    parser.add_argument('--include-preferences', action='store_true')
    parser.add_argument('--apply', action='store_true')
    try:
        run(parser.parse_args())
    except Exception as error:
        # Do not expose extension names, preference values, or third-party exception text.
        raise SystemExit('Migration failed (' + type(error).__name__ + '); destination backup preserved.')
