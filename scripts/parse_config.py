#!/usr/bin/env python3
"""
Sui Tools Configuration Parser
Parses config.yml and generates Prometheus configuration dynamically
"""

import yaml
import json
import sys
import os
from typing import Dict, List, Any


def load_config(config_file: str) -> Dict[str, Any]:
    """Load and validate configuration from YAML file."""
    try:
        with open(config_file, "r") as f:
            config = yaml.safe_load(f)

        if not config:
            raise ValueError("Configuration file is empty")

        return config
    except FileNotFoundError:
        print(f"ERROR: Configuration file not found: {config_file}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"ERROR: Invalid YAML in configuration file: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to load configuration: {e}", file=sys.stderr)
        sys.exit(1)


def validate_bridges_config(bridges: List[Dict[str, Any]]) -> None:
    """Validate bridges configuration structure."""
    if not isinstance(bridges, list):
        raise ValueError("bridges must be a list")

    for i, bridge in enumerate(bridges):
        if not isinstance(bridge, dict):
            raise ValueError(f"Bridge {i} must be a dictionary")

        required_fields = ["alias", "target", "public_address"]
        for field in required_fields:
            if field not in bridge:
                raise ValueError(f"Bridge {i} missing required field: {field}")
            if not bridge[field]:
                raise ValueError(f"Bridge {i} field '{field}' cannot be empty")

        # Validate alerts configuration if present
        if "alerts" in bridge:
            validate_alerts_config(bridge["alerts"], i)
        else:
            # Set default alerts if not specified
            bridge["alerts"] = get_default_alerts()


def validate_alerts_config(alerts: Dict[str, Any], bridge_index: int) -> None:
    """Validate alerts configuration structure."""
    if not isinstance(alerts, dict):
        raise ValueError(f"Bridge {bridge_index} alerts must be a dictionary")

    valid_alert_types = {
        # Common alerts
        "uptime",
        "metrics_public_key_availability",
        "ingress_access",
        "voting_power",
        # Client-disabled alerts
        "bridge_requests_errors",
        "bridge_high_latency",
        "bridge_high_cache_misses",
        "bridge_rpc_errors",
        # Client-enabled alerts
        "stale_sui_sync",
        "stale_eth_sync",
        "stale_eth_finalization",
        "low_gas_balance",
    }

    for alert_type, enabled in alerts.items():
        if alert_type not in valid_alert_types:
            raise ValueError(
                f"Bridge {bridge_index} has invalid alert type: {alert_type}"
            )
        if not isinstance(enabled, bool):
            raise ValueError(
                f"Bridge {bridge_index} alert '{alert_type}' must be a boolean"
            )


def get_default_alerts() -> Dict[str, bool]:
    """Get default alerts configuration with all alerts enabled."""
    return {
        # Common alerts
        "uptime": True,
        "metrics_public_key_availability": True,
        "ingress_access": True,
        "voting_power": True,
        # Client-disabled alerts
        "bridge_requests_errors": True,
        "bridge_high_latency": True,
        "bridge_high_cache_misses": True,
        "bridge_rpc_errors": True,
        # Client-enabled alerts
        "stale_sui_sync": True,
        "stale_eth_sync": True,
        "stale_eth_finalization": True,
        "low_gas_balance": True,
    }


def generate_alert_rules(bridges: List[Dict[str, Any]], output_dir: str) -> None:
    """Generate bridge-specific alert rules organized by bridge."""

    import os

    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Generate individual bridge alert files
    for i, bridge in enumerate(bridges):
        alias = bridge["alias"]
        alerts = bridge.get("alerts", get_default_alerts())

        # Sanitize alias for filename
        safe_alias = alias.lower().replace(" ", "_").replace("-", "_")
        bridge_file = os.path.join(
            output_dir, f"sui_bridge_{i}_{safe_alias}_alerts.yml"
        )

        bridge_rules = {"groups": []}

        # Common alerts group for this bridge
        common_alerts = []

        # Client-disabled alerts group for this bridge
        client_disabled_alerts = []

        # Client-enabled alerts group for this bridge
        client_enabled_alerts = []

        # Generate bridge-specific alert rules based on enabled alerts
        if alerts.get("uptime", True):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_Uptime_{alias.replace(' ', '_')}",
                    "expr": f'increase(uptime{{service="sui_bridge", environment="{alias}"}}[10m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "uptime",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Critical uptime on {{ $labels.instance }} ({alias})",
                        "description": f"The uptime for SUI Bridge Node instance {{ $labels.instance }} ({alias}) has not increased in the last 10 minutes, suggesting a restart or failure.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "2",
                    },
                }
            )

        if alerts.get("metrics_public_key_availability", True):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_MetricsPublicKeyAvailability_{alias.replace(' ', '_')}",
                    "expr": f'probe_success{{service="sui_bridge_health_check", environment="{alias}"}} == 0',
                    "for": "2m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "metrics_public_key_availability",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Metrics Public Key Unavailable (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The metrics public key endpoint for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is not accessible.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "2",
                    },
                }
            )

        if alerts.get("ingress_access", True):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_IngressAccess_{alias.replace(' ', '_')}",
                    "expr": f'probe_success{{service="sui_bridge_ingress_check", environment="{alias}"}} == 0',
                    "for": "2m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "ingress_access",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Ingress Unavailable (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The public ingress endpoint for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is not accessible.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "2",
                    },
                }
            )

        if alerts.get("voting_power", True):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_VotingPower_{alias.replace(' ', '_')}",
                    "expr": f'current_bridge_voting_rights{{service="sui_bridge", authority="${{SUI_VALIDATOR}}", environment="{alias}"}} == 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "voting_power",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Zero Bridge Voting Rights (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The SUI Bridge Node instance {{ $labels.instance }} ({alias}) has zero voting rights, indicating a potential issue with the validator's authority.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "288",
                    },
                }
            )

        # Client-disabled alerts
        if alerts.get("bridge_requests_errors", True):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_BridgeRequestErrors_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_err_requests{{service="sui_bridge", type="handle_sui_tx_digest", environment="{alias}"}}[5m]) > 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "bridge_requests_errors",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Request Errors Detected (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The SUI Bridge Node instance {{ $labels.instance }} ({alias}) detected errors while handling SUI transaction digests in the last 5 minutes.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "294",
                    },
                }
            )

        if alerts.get("bridge_high_latency", True):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_HighETHRPCLatency_{alias.replace(' ', '_')}",
                    "expr": f'bridge_eth_rpc_queries_latency{{service="sui_bridge", environment="{alias}"}} > 5000',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "bridge_high_latency",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"High ETH RPC Latency (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The ETH RPC queries latency for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is above 5 seconds.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "294",
                    },
                }
            )

        if alerts.get("bridge_high_cache_misses", True):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_HighCacheMisses_{alias.replace(' ', '_')}",
                    "expr": f'(rate(bridge_signer_with_cache_miss{{service="sui_bridge", environment="{alias}"}}[5m]) / (rate(bridge_signer_with_cache_hit{{service="sui_bridge", environment="{alias}"}}[5m]) + rate(bridge_signer_with_cache_miss{{service="sui_bridge", environment="{alias}"}}[5m]))) > 0.5',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "bridge_high_cache_misses",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"High Cache Miss Rate (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The cache miss rate for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is above 50%.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "305",
                    },
                }
            )

        if alerts.get("bridge_rpc_errors", True):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_SUIRPCErrors_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_sui_rpc_errors{{service="sui_bridge", environment="{alias}"}}[5m]) > 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "bridge_rpc_errors",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"SUI RPC Errors Detected (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"SUI RPC errors detected for SUI Bridge Node instance {{ $labels.instance }} ({alias}) in the last 5 minutes.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "322",
                    },
                }
            )

        # Client-enabled alerts
        if alerts.get("stale_sui_sync", True):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_StaleSUISync_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_last_synced_sui_checkpoints{{service="sui_bridge", module_name="bridge", environment="{alias}"}}[30m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "stale_sui_sync",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Last Synced Checkpoints Not Increasing (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Last Synced Checkpoints on {{ $labels.instance }} ({alias}) are not increasing for the last 30 minutes.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "331",
                    },
                }
            )

        if alerts.get("stale_eth_sync", True):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_StaleETHSync_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_last_synced_eth_blocks{{service="sui_bridge", environment="{alias}"}}[30m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "stale_eth_sync",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Last Synced ETH Blocks Not Increasing (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Last Synced ETH Blocks on {{ $labels.instance }} ({alias}) are not increasing for the last 30 minutes.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "324",
                    },
                }
            )

        if alerts.get("stale_eth_finalization", True):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_StaleETHFinalization_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_last_finalized_eth_block{{service="sui_bridge", environment="{alias}"}}[10m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "stale_eth_finalization",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Finalized ETH Block Not Increasing (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Finalized ETH Block on {{ $labels.instance }} ({alias}) is not increasing for the last 10 minutes.",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "324",
                    },
                }
            )

        if alerts.get("low_gas_balance", True):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_LowGasBalance_{alias.replace(' ', '_')}",
                    "expr": f'bridge_gas_coin_balance{{service="sui_bridge", environment="{alias}"}} < 10000000000',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "environment": f'"{alias}"',
                        "alert_type": "low_gas_balance",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Client Balance Running Low (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Client Balance on {{ $labels.instance }} ({alias}) is running out of tokens (below 10 SUI).",
                        "__dashboardUid__": "ctles38bbprkmttbdkv0hijk",
                        "__panelId__": "316",
                    },
                }
            )

        # Add groups to bridge rules
        if common_alerts:
            bridge_rules["groups"].append(
                {
                    "name": f"sui_bridge_common_alerts_{alias.replace(' ', '_')}",
                    "rules": common_alerts,
                }
            )

        if client_disabled_alerts:
            bridge_rules["groups"].append(
                {
                    "name": f"sui_bridge_client_disabled_alerts_{alias.replace(' ', '_')}",
                    "rules": client_disabled_alerts,
                }
            )

        if client_enabled_alerts:
            bridge_rules["groups"].append(
                {
                    "name": f"sui_bridge_client_enabled_alerts_{alias.replace(' ', '_')}",
                    "rules": client_enabled_alerts,
                }
            )

        # Write bridge-specific alert rules file
        try:
            with open(bridge_file, "w") as f:
                yaml.dump(bridge_rules, f, default_flow_style=False, sort_keys=False)
            print(
                f"Generated bridge-specific alert rules: {bridge_file}", file=sys.stderr
            )
        except Exception as e:
            print(
                f"ERROR: Failed to write bridge alert rules for {alias}: {e}",
                file=sys.stderr,
            )
            sys.exit(1)


def generate_prometheus_config(bridges: List[Dict[str, Any]], output_file: str) -> None:
    """Generate Prometheus configuration file."""

    # Base Prometheus configuration
    prometheus_config = {
        "global": {
            "scrape_interval": "15s",
            "evaluation_interval": "15s",
            "external_labels": {"cluster": "sui-monitoring", "replica": "prometheus-1"},
        },
        "rule_files": ["/etc/prometheus/rules/*.yml"],
        "alerting": {
            "alertmanagers": [
                {"static_configs": [{"targets": ["${ALERTMANAGER_TARGET}"]}]}
            ]
        },
        "scrape_configs": [
            {
                "job_name": "prometheus",
                "static_configs": [{"targets": ["${PROMETHEUS_TARGET}"]}],
                "scrape_interval": "5s",
                "metrics_path": "/metrics",
            }
        ],
    }

    # Add bridge scrape configs
    for bridge in bridges:
        alias = bridge["alias"]
        target = bridge["target"]
        public_address = bridge["public_address"]

        # Sanitize target for scheme detection
        scheme = "http"
        clean_target = target
        if target.startswith("https://"):
            scheme = "https"
            clean_target = target[8:]
        elif target.startswith("http://"):
            scheme = "http"
            clean_target = target[7:]

        # Bridge metrics scrape config
        bridge_job = {
            "job_name": f'sui_bridge_{alias.lower().replace(" ", "_")}',
            "static_configs": [
                {
                    "targets": [clean_target],
                    "labels": {
                        "service": "sui_bridge",
                        "environment": alias,
                        "configured": "true",
                    },
                }
            ],
            "scrape_interval": "15s",
            "metrics_path": "/metrics",
            "scrape_timeout": "10s",
            "scheme": scheme,
            "honor_labels": True,
            "relabel_configs": [
                {"target_label": "instance", "replacement": clean_target}
            ],
        }
        prometheus_config["scrape_configs"].append(bridge_job)

        # Bridge health check config
        health_job = {
            "job_name": f'sui_bridge_{alias.lower().replace(" ", "_")}_metrics_public_key_check',
            "metrics_path": "/probe",
            "params": {"module": ["http_2xx"]},
            "static_configs": [
                {
                    "targets": [f"{public_address}/metrics_pub_key"],
                    "labels": {
                        "service": "sui_bridge_health_check",
                        "environment": alias,
                        "configured": "true",
                    },
                }
            ],
            "scrape_interval": "1m",
            "scrape_timeout": "10s",
            "relabel_configs": [
                {"source_labels": ["__address__"], "target_label": "__param_target"},
                {
                    "source_labels": ["__param_target"],
                    "target_label": "instance",
                    "replacement": clean_target,
                },
                {
                    "target_label": "__address__",
                    "replacement": "${BLACKBOX_EXPORTER_ADDRESS}",
                },
            ],
        }
        prometheus_config["scrape_configs"].append(health_job)

        # Bridge ingress check config
        ingress_job = {
            "job_name": f'sui_bridge_{alias.lower().replace(" ", "_")}_ingress_check',
            "metrics_path": "/probe",
            "params": {"module": ["http_2xx"]},
            "static_configs": [
                {
                    "targets": [public_address],
                    "labels": {
                        "service": "sui_bridge_ingress_check",
                        "environment": alias,
                        "configured": "true",
                    },
                }
            ],
            "scrape_interval": "1m",
            "scrape_timeout": "10s",
            "relabel_configs": [
                {"source_labels": ["__address__"], "target_label": "__param_target"},
                {
                    "source_labels": ["__param_target"],
                    "target_label": "instance",
                    "replacement": clean_target,
                },
                {
                    "target_label": "__address__",
                    "replacement": "${BLACKBOX_EXPORTER_ADDRESS}",
                },
            ],
        }
        prometheus_config["scrape_configs"].append(ingress_job)

    # Write configuration file
    try:
        with open(output_file, "w") as f:
            yaml.dump(prometheus_config, f, default_flow_style=False, sort_keys=False)
        print(f"Generated Prometheus configuration: {output_file}", file=sys.stderr)
    except Exception as e:
        print(f"ERROR: Failed to write Prometheus config: {e}", file=sys.stderr)
        sys.exit(1)


def export_bridge_variables(bridges: List[Dict[str, Any]], sui_validator: str) -> None:
    """Export bridge configuration as shell environment variables."""
    print("# Bridge configuration variables")
    print(f"export SUI_BRIDGES_COUNT={len(bridges)}")
    print(f"export SUI_VALIDATOR='{sui_validator}'")

    for i, bridge in enumerate(bridges):
        alias = bridge["alias"]
        target = bridge["target"]
        public_address = bridge["public_address"]
        alerts = bridge.get("alerts", get_default_alerts())

        # Export individual bridge variables
        print(f"export SUI_BRIDGE_{i}_ALIAS='{alias}'")
        print(f"export SUI_BRIDGE_{i}_TARGET='{target}'")
        print(f"export SUI_BRIDGE_{i}_PUBLIC_ADDRESS='{public_address}'")

        # Export alert flags as individual variables
        for alert_type, enabled in alerts.items():
            print(
                f"export SUI_BRIDGE_{i}_ALERT_{alert_type.upper()}='{str(enabled).lower()}'"
            )

    # Export as JSON for complex parsing - write to separate file to avoid shell parsing issues
    bridges_json = json.dumps(bridges, indent=2)
    print(f"export SUI_BRIDGES_CONFIG_FILE='generated_configs/bridges.json'")

    # Write JSON to file
    with open("generated_configs/bridges.json", "w") as f:
        f.write(bridges_json)


def main():
    """Main function."""
    if len(sys.argv) != 4:
        print(
            "Usage: parse_config.py <config.yml> <prometheus.yml> <alert_rules.yml>",
            file=sys.stderr,
        )
        sys.exit(1)

    config_file = sys.argv[1]
    prometheus_file = sys.argv[2]
    alert_rules_file = sys.argv[3]

    # Load configuration
    config = load_config(config_file)

    # Validate bridges configuration
    if "bridges" not in config:
        print("ERROR: No 'bridges' section found in configuration", file=sys.stderr)
        sys.exit(1)

    bridges = config["bridges"]
    validate_bridges_config(bridges)

    # Get SUI_VALIDATOR from config
    sui_validator = config.get("sui", {}).get("validator", "")

    # Generate Prometheus configuration
    generate_prometheus_config(bridges, prometheus_file)

    # Generate bridge-specific alert rules
    generate_alert_rules(bridges, alert_rules_file)

    # Export bridge variables
    export_bridge_variables(bridges, sui_validator)

    print(f"Successfully parsed {len(bridges)} bridge(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
