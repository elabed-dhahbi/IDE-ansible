# Automatic Version Detection

## Overview

The playbook includes automatic version detection from the offline package directory. This eliminates the need to manually update version numbers when new packages are available.

## How It Works

### 1. Package Scanning (`sync_packages.sh`)

The `sync_packages.sh` script scans the `/tmp/offline` directory (or configured `paths.offline_dir`) and automatically detects package versions from filenames.

**Supported Packages:**
- PostgreSQL (from `postgresql15-*.rpm`)
- DMC (from `SCPdmc-*.tar.gz`)
- MMG (from `SCPmmg-*.rpm`)
- MMSOAP (from `SCPmmsoap-*.rpm`)
- SMPPC (from `SCPsmppc-*.rpm`)
- SLS (from `SCPsls-*.tar.gz`)
- DRS (from `SCPdrs-*.rpm`)
- OpenSearch (from `opensearch-*-linux-x64.rpm`)
- Logstash OSS (from `logstash-oss-*-x86_64.rpm`)
- Zabbix (from `zabbix-server-pgsql-*-release*.el9.x86_64.rpm`)

### 2. Version File Updates

The script updates **both** files for seamless transition:

1. **Primary**: `ansible/vars/release.yml` (new centralized version file)
2. **Backward Compatibility**: `config/values.yaml` (legacy file)

### 3. Version Key Mapping

The script automatically maps detected package keys to the appropriate variable names:

| Detected Key | release.yml Key | values.yaml Key |
|-------------|----------------|-----------------|
| `postgres` | `postgresql_full_version` | `versions.postgres` |
| `postgresql_major_version` | `postgresql_major_version` | - |
| `dmc` | `dmc_version` | `versions.dmc` |
| `mmg` | `mmg_version` | `versions.mmg` |
| `opensearch` | `opensearch_version` | `versions.opensearch` |
| `zabbix` | `zabbix_version` | `versions.zabbix` |

## Usage

### Automatic Sync (Recommended)

Run the sync command before installation:

```bash
make sync-packages
```

Or directly:

```bash
bash scripts/sync_packages.sh
```

### Manual Override

If you need to override detected versions, edit `ansible/vars/release.yml`:

```yaml
dmc_version: "4.6.34"  # Override detected version
```

### Environment Variable

You can specify a custom offline directory:

```bash
OFFLINE_DIR=/path/to/packages make sync-packages
```

## Integration with Package Validation

The `check_offline_artifacts.sh` script also supports the new variable structure:

1. **Checks `vars/release.yml` first** for version information
2. **Falls back to `config/values.yaml`** for backward compatibility
3. **Uses `vars/env/default.yml`** for environment configuration

### Running Package Validation

```bash
make prepare
```

Or directly:

```bash
bash scripts/check_offline_artifacts.sh
```

## Workflow

### Typical Installation Workflow

1. **Place packages** in `/tmp/offline` (or configured directory)
2. **Sync versions**: `make sync-packages`
   - Scans offline directory
   - Detects all package versions
   - Updates `vars/release.yml` and `config/values.yaml`
3. **Validate packages**: `make prepare`
   - Checks all required packages are present
   - Validates against inventory groups
   - Uses versions from `vars/release.yml`
4. **Install**: `make install`
   - Playbook uses versions from `vars/release.yml`

### Example Output

```bash
$ make sync-packages

=== Syncing Package Versions from Offline Directory ===
Offline directory: /tmp/offline
Config file: config/values.yaml
Release file: ansible/vars/release.yml

✓ Detected PostgreSQL version: 15.14 (major: 15)
✓ Detected DMC version: 4.6.33
✓ Detected MMG version: 4.6.21
✓ Detected OpenSearch version: 3.2.0
✓ Detected Zabbix version: 7.4.2

=== Summary of Detected Versions ===
  postgres: 15.14
  postgresql_major_version: 15
  postgresql_full_version: 15.14
  dmc: 4.6.33
  mmg: 4.6.21
  opensearch: 3.2.0
  zabbix: 7.4.2

=== Updating Version Files ===
Updating ansible/vars/release.yml (centralized versions)...
✓ Updated postgresql_full_version to 15.14
✓ Updated postgresql_major_version to 15
✓ Updated dmc_version to 4.6.33
✓ Updated mmg_version to 4.6.21
✓ Updated opensearch_version to 3.2.0
✓ Updated zabbix_version to 7.4.2

Updating config/values.yaml (backward compatibility)...
✓ Updated versions.postgres to 15.14
✓ Updated versions.dmc to 4.6.33
✓ Updated versions.mmg to 4.6.21
✓ Updated versions.opensearch to 3.2.0
✓ Updated versions.zabbix to 7.4.2

✓ Successfully updated 11 version(s) in ansible/vars/release.yml
✓ Successfully updated 5 version(s) in config/values.yaml
✓ Package version sync completed successfully
Primary version file: ansible/vars/release.yml
Backward compatibility: config/values.yaml
```

## Benefits

1. **No Manual Updates**: Versions are automatically detected from package files
2. **Single Source of Truth**: `vars/release.yml` centralizes all versions
3. **Backward Compatible**: Still updates `config/values.yaml` for existing playbooks
4. **Error Prevention**: Reduces risk of version mismatches
5. **Easy Upgrades**: Just place new packages and run `sync-packages`

## Troubleshooting

### No Versions Detected

**Problem**: Script reports "No package versions detected"

**Solutions**:
- Verify packages are in the correct directory (`/tmp/offline` by default)
- Check package filenames match expected patterns
- Ensure packages are not in subdirectories (script checks `-maxdepth 1`)

### Version Not Updated

**Problem**: Detected version but update failed

**Solutions**:
- Check if key exists in `vars/release.yml`
- Verify file permissions (script needs write access)
- Check for YAML syntax errors in target file

### Wrong Version Detected

**Problem**: Script extracts incorrect version from filename

**Solutions**:
- Check filename pattern matches expected format
- Verify regex patterns in `sync_packages.sh`
- Manually override in `vars/release.yml` if needed

## Advanced Usage

### Custom Offline Directory

```bash
OFFLINE_DIR=/custom/path/to/packages bash scripts/sync_packages.sh
```

### Skip Backward Compatibility Update

Edit `sync_packages.sh` to comment out the `config/values.yaml` update section if you only want to use `vars/release.yml`.

### Add New Package Detection

To add detection for a new package:

1. Add detection logic in `sync_packages.sh`:
   ```bash
   new_package_file=$(find_latest_version "NewPackage-*.rpm" "$OFFLINE_DIR")
   if [[ -n "$new_package_file" ]]; then
       version=$(extract_version "NewPackage-([0-9]+\.[0-9]+\.[0-9]+)" "$(basename "$new_package_file")")
       if [[ -n "$version" ]]; then
           detected_versions["new_package"]="$version"
       fi
   fi
   ```

2. Add mapping in `release_key_mapping`:
   ```bash
   release_key_mapping["new_package"]="new_package_version"
   ```

3. Add key to `vars/release.yml`:
   ```yaml
   new_package_version: "1.0.0"
   ```

## Integration with Makefile

The Makefile includes automatic version syncing:

```makefile
prepare: sync-packages
    # ... validation steps
```

This ensures versions are always up-to-date before installation.

## Best Practices

1. **Always run `sync-packages`** before installation
2. **Commit `vars/release.yml`** to version control
3. **Review detected versions** before proceeding with installation
4. **Use `make prepare`** to validate packages after syncing
5. **Keep backups** (script creates `.bak` files automatically)

---

**Last Updated**: 2025-12-02  
**Status**: Integrated with centralized variable structure







