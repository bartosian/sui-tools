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


def validate_validators_config(validators: List[Dict[str, Any]]) -> None:
    """Validate validators configuration structure."""
    if not isinstance(validators, list):
        raise ValueError("validators must be a list")

    for i, validator in enumerate(validators):
        if not isinstance(validator, dict):
            raise ValueError(f"Validator {i} must be a dictionary")

        required_fields = ["alias", "target"]
        for field in required_fields:
            if field not in validator:
                raise ValueError(f"Validator {i} missing required field: {field}")
            if not validator[field]:
                raise ValueError(f"Validator {i} field '{field}' cannot be empty")

        # Validate alerts configuration if present
        if "alerts" in validator:
            validate_validator_alerts_config(validator["alerts"], i)
        else:
            # Set default alerts if not specified
            validator["alerts"] = get_default_validator_alerts()


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


def validate_validator_alerts_config(
    alerts: Dict[str, Any], validator_index: int
) -> None:
    """Validate validator alerts configuration structure."""
    if not isinstance(alerts, dict):
        raise ValueError(f"Validator {validator_index} alerts must be a dictionary")

    valid_alert_types = {
        "uptime",
        "reputation_rank",
        "voting_power",
        "tx_processing_latency_p95",
        "tx_processing_latency_p95_10s",
        "tx_processing_latency_p95_3s",
        "tx_processing_latency_p50",
        "proposal_latency",
        "consensus_block_commit_rate",
        "committed_round_rate",
        "fullnode_connectivity",
    }

    for alert_type, enabled in alerts.items():
        if alert_type not in valid_alert_types:
            raise ValueError(
                f"Validator {validator_index} has invalid alert type: {alert_type}"
            )
        if not isinstance(enabled, bool):
            raise ValueError(
                f"Validator {validator_index} alert '{alert_type}' must be a boolean"
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


def get_default_validator_alerts() -> Dict[str, bool]:
    """Get default validator alerts configuration with all alerts enabled."""
    return {
        "uptime": True,
        "reputation_rank": True,
        "voting_power": True,
        "tx_processing_latency_p95": True,
        "tx_processing_latency_p95_10s": True,
        "tx_processing_latency_p95_3s": True,
        "tx_processing_latency_p50": True,
        "proposal_latency": True,
        "consensus_block_commit_rate": True,
        "committed_round_rate": True,
        "fullnode_connectivity": True,
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
        if alerts.get("uptime", False):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_Uptime_{alias.replace(' ', '_')}",
                    "expr": f'increase(uptime{{service="sui_bridge", alias="{alias}"}}[10m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "uptime",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Critical uptime on {{ $labels.instance }} ({alias})",
                        "description": f"The uptime for SUI Bridge Node instance {{ $labels.instance }} ({alias}) has not increased in the last 10 minutes, suggesting a restart or failure.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "2",
                    },
                }
            )

        if alerts.get("metrics_public_key_availability", False):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_MetricsPublicKeyAvailability_{alias.replace(' ', '_')}",
                    "expr": f'probe_success{{service="sui_bridge_health_check", alias="{alias}"}} == 0',
                    "for": "2m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "metrics_public_key_availability",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Metrics Public Key Unavailable (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The metrics public key endpoint for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is not accessible.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "2",
                    },
                }
            )

        if alerts.get("ingress_access", False):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_IngressAccess_{alias.replace(' ', '_')}",
                    "expr": f'probe_success{{service="sui_bridge_ingress_check", alias="{alias}"}} == 0',
                    "for": "2m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "ingress_access",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Ingress Unavailable (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The public ingress endpoint for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is not accessible.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "2",
                    },
                }
            )

        if alerts.get("voting_power", False):
            common_alerts.append(
                {
                    "alert": f"SuiBridge_VotingPower_{alias.replace(' ', '_')}",
                    "expr": f'current_bridge_voting_rights{{service="sui_bridge", authority="${{SUI_VALIDATOR}}", alias="{alias}"}} == 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "voting_power",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Zero Bridge Voting Rights (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The SUI Bridge Node instance {{ $labels.instance }} ({alias}) has zero voting rights, indicating a potential issue with the validator's authority.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "288",
                    },
                }
            )

        # Client-disabled alerts
        if alerts.get("bridge_requests_errors", False):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_BridgeRequestErrors_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_err_requests{{service="sui_bridge", type="handle_sui_tx_digest", alias="{alias}"}}[5m]) > 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "bridge_requests_errors",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Request Errors Detected (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The SUI Bridge Node instance {{ $labels.instance }} ({alias}) detected errors while handling SUI transaction digests in the last 5 minutes.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "294",
                    },
                }
            )

        if alerts.get("bridge_high_latency", False):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_HighETHRPCLatency_{alias.replace(' ', '_')}",
                    "expr": f'bridge_eth_rpc_queries_latency{{service="sui_bridge", alias="{alias}"}} > 5000',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "bridge_high_latency",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"High ETH RPC Latency (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The ETH RPC queries latency for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is above 5 seconds.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "294",
                    },
                }
            )

        if alerts.get("bridge_high_cache_misses", False):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_HighCacheMisses_{alias.replace(' ', '_')}",
                    "expr": f'(rate(bridge_signer_with_cache_miss{{service="sui_bridge", alias="{alias}"}}[5m]) / (rate(bridge_signer_with_cache_hit{{service="sui_bridge", alias="{alias}"}}[5m]) + rate(bridge_signer_with_cache_miss{{service="sui_bridge", alias="{alias}"}}[5m]))) > 0.5',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "bridge_high_cache_misses",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"High Cache Miss Rate (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The cache miss rate for SUI Bridge Node instance {{ $labels.instance }} ({alias}) is above 50%.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "305",
                    },
                }
            )

        if alerts.get("bridge_rpc_errors", False):
            client_disabled_alerts.append(
                {
                    "alert": f"SuiBridge_SUIRPCErrors_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_sui_rpc_errors{{service="sui_bridge", alias="{alias}"}}[5m]) > 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "bridge_rpc_errors",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"SUI RPC Errors Detected (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"SUI RPC errors detected for SUI Bridge Node instance {{ $labels.instance }} ({alias}) in the last 5 minutes.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "322",
                    },
                }
            )

        # Client-enabled alerts
        if alerts.get("stale_sui_sync", False):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_StaleSUISync_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_last_synced_sui_checkpoints{{service="sui_bridge", module_name="bridge", alias="{alias}"}}[30m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "stale_sui_sync",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Last Synced Checkpoints Not Increasing (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Last Synced Checkpoints on {{ $labels.instance }} ({alias}) are not increasing for the last 30 minutes.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "331",
                    },
                }
            )

        if alerts.get("stale_eth_sync", False):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_StaleETHSync_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_last_synced_eth_blocks{{service="sui_bridge", alias="{alias}"}}[30m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "stale_eth_sync",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Last Synced ETH Blocks Not Increasing (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Last Synced ETH Blocks on {{ $labels.instance }} ({alias}) are not increasing for the last 30 minutes.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "324",
                    },
                }
            )

        if alerts.get("stale_eth_finalization", False):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_StaleETHFinalization_{alias.replace(' ', '_')}",
                    "expr": f'increase(bridge_last_finalized_eth_block{{service="sui_bridge", alias="{alias}"}}[10m]) == 0',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "stale_eth_finalization",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Finalized ETH Block Not Increasing (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Finalized ETH Block on {{ $labels.instance }} ({alias}) is not increasing for the last 10 minutes.",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
                        "__panelId__": "324",
                    },
                }
            )

        if alerts.get("low_gas_balance", False):
            client_enabled_alerts.append(
                {
                    "alert": f"SuiBridge_LowGasBalance_{alias.replace(' ', '_')}",
                    "expr": f'bridge_gas_coin_balance{{service="sui_bridge", alias="{alias}"}} < 10000000000',
                    "for": "1m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_bridge",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "low_gas_balance",
                        "bridge_index": str(i),
                        "bridge_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Bridge Client Balance Running Low (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"Bridge Client Balance on {{ $labels.instance }} ({alias}) is running out of tokens (below 10 SUI).",
                        "__dashboardUid__": "d3sdagobbprlcrf8dh3g",
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


def generate_validator_alert_rules(
    validators: List[Dict[str, Any]], sui_validator: str, output_dir: str
) -> None:
    """Generate validator-specific alert rules organized by validator."""

    import os

    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Generate individual validator alert files
    for i, validator in enumerate(validators):
        alias = validator["alias"]
        alerts = validator.get("alerts", get_default_validator_alerts())

        # Sanitize alias for filename
        safe_alias = alias.lower().replace(" ", "_").replace("-", "_")
        validator_file = os.path.join(
            output_dir, f"sui_validator_{i}_{safe_alias}_alerts.yml"
        )

        validator_rules = {"groups": []}
        critical_alerts = []
        warning_alerts = []

        # Generate validator-specific alert rules based on enabled alerts
        if alerts.get("uptime", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_Uptime_{alias.replace(' ', '_')}",
                    "expr": f'rate(uptime{{alias="{alias}"}}[5m]) == 0',
                    "for": "2m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "uptime",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Validator Uptime Issue (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The uptime for SUI Validator instance {{ $labels.instance }} ({alias}) is not increasing, suggesting a potential restart or failure.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "347",
                    },
                }
            )

        if alerts.get("reputation_rank", False):
            warning_alerts.append(
                {
                    "alert": f"SuiValidator_ReputationRank_{alias.replace(' ', '_')}",
                    "expr": f'(scalar(consensus_reputation_scores{{alias="{alias}", authority="{sui_validator}"}}) <= bool max(bottomk(scalar(consensus_handler_num_low_scoring_authorities{{alias="{alias}"}}), consensus_reputation_scores{{alias="{alias}"}}))) == 1',
                    "for": "30m",
                    "labels": {
                        "severity": "warning",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "reputation_rank",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Validator Low Reputation Rank (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The SUI Validator instance {{ $labels.instance }} ({alias}) is in the bottom N low-scoring validators based on consensus reputation scores.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "366",
                    },
                }
            )

        if alerts.get("voting_power", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_VotingPower_{alias.replace(' ', '_')}",
                    "expr": f'current_voting_right{{alias="{alias}"}} == 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "voting_power",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Zero Validator Voting Power (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The SUI Validator instance {{ $labels.instance }} ({alias}) has zero voting power, indicating a critical issue with the validator's authority.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "268",
                    },
                }
            )

        if alerts.get("tx_processing_latency_p95", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_TxProcessingLatencyP95_{alias.replace(' ', '_')}",
                    "expr": f'histogram_quantile(0.95, rate(validator_service_handle_certificate_consensus_latency_bucket{{alias="{alias}"}}[5m])) > 15000',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "tx_processing_latency_p95",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"High Transaction Processing Latency P95 (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The 95th percentile transaction processing latency for SUI Validator instance {{ $labels.instance }} ({alias}) is above 15 seconds.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "295",
                    },
                }
            )

        if alerts.get("tx_processing_latency_p95_10s", False):
            warning_alerts.append(
                {
                    "alert": f"SuiValidator_TxProcessingLatencyP95_10s_{alias.replace(' ', '_')}",
                    "expr": f'histogram_quantile(0.95, rate(validator_service_handle_certificate_consensus_latency_bucket{{alias="{alias}"}}[5m])) > 10000',
                    "for": "5m",
                    "labels": {
                        "severity": "warning",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "tx_processing_latency_p95_10s",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Elevated Transaction Processing Latency P95 (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The 95th percentile transaction processing latency for SUI Validator instance {{ $labels.instance }} ({alias}) is above 10 seconds.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "295",
                    },
                }
            )

        if alerts.get("tx_processing_latency_p95_3s", False):
            warning_alerts.append(
                {
                    "alert": f"SuiValidator_TxProcessingLatencyP95_3s_{alias.replace(' ', '_')}",
                    "expr": f'histogram_quantile(0.95, rate(validator_service_handle_certificate_consensus_latency_bucket{{alias="{alias}"}}[5m])) > 3000',
                    "for": "5m",
                    "labels": {
                        "severity": "warning",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "tx_processing_latency_p95_3s",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Moderate Transaction Processing Latency P95 (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The 95th percentile transaction processing latency for SUI Validator instance {{ $labels.instance }} ({alias}) is above 3 seconds.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "295",
                    },
                }
            )

        if alerts.get("tx_processing_latency_p50", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_TxProcessingLatencyP50_{alias.replace(' ', '_')}",
                    "expr": f'histogram_quantile(0.50, rate(validator_service_handle_certificate_consensus_latency_bucket{{alias="{alias}"}}[5m])) > 5000',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "tx_processing_latency_p50",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"High Transaction Processing Latency P50 (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The 50th percentile transaction processing latency for SUI Validator instance {{ $labels.instance }} ({alias}) is above 5 seconds.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "295",
                    },
                }
            )

        if alerts.get("proposal_latency", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_ProposalLatency_{alias.replace(' ', '_')}",
                    "expr": f'rate(consensus_quorum_receive_latency_sum{{alias="{alias}"}}[5m]) / rate(consensus_quorum_receive_latency_count{{alias="{alias}"}}[5m]) > 2',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "proposal_latency",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"High Consensus Proposal Latency (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The consensus proposal latency for SUI Validator instance {{ $labels.instance }} ({alias}) is above 2 seconds.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "342",
                    },
                }
            )

        if alerts.get("consensus_block_commit_rate", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_ConsensusBlockCommitRate_{alias.replace(' ', '_')}",
                    "expr": f'sum(rate(consensus_proposed_blocks{{alias="{alias}", force="false"}}[5m])) + sum(rate(consensus_proposed_blocks{{alias="{alias}", force="true"}}[5m])) < 3',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "consensus_block_commit_rate",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Low Consensus Block Commit Rate (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The consensus block commit rate for SUI Validator instance {{ $labels.instance }} ({alias}) is below 3 blocks per second.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "295",
                    },
                }
            )

        if alerts.get("committed_round_rate", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_CommittedRoundRate_{alias.replace(' ', '_')}",
                    "expr": f'rate(consensus_last_committed_leader_round{{alias="{alias}"}}[2m]) < 3',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "committed_round_rate",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Low Committed Round Rate (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The committed round rate for SUI Validator instance {{ $labels.instance }} ({alias}) is below 3 rounds per second.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "241",
                    },
                }
            )

        if alerts.get("fullnode_connectivity", False):
            critical_alerts.append(
                {
                    "alert": f"SuiValidator_FullnodeConnectivity_{alias.replace(' ', '_')}",
                    "expr": f'rate(total_rpc_err{{alias="{alias}", name="{sui_validator}"}}[2m]) > 0',
                    "for": "5m",
                    "labels": {
                        "severity": "critical",
                        "service": "sui_validator",
                        "instance": "{{ $labels.instance }}",
                        "alias": f'"{alias}"',
                        "alert_type": "fullnode_connectivity",
                        "validator_index": str(i),
                        "validator_alias": alias,
                    },
                    "annotations": {
                        "summary": f"Fullnode Connectivity Issues (Instance: {{ $labels.instance }}, Environment: {alias})",
                        "description": f"The SUI Validator instance {{ $labels.instance }} ({alias}) is experiencing RPC errors indicating connectivity issues with fullnodes.",
                        "__dashboardUid__": "d3sdas8bbprlibnio2n0",
                        "__panelId__": "390",
                    },
                }
            )

        # Add critical alerts group to validator rules
        if critical_alerts:
            validator_rules["groups"].append(
                {
                    "name": f"sui_validator_critical_alerts_{alias.replace(' ', '_')}",
                    "rules": critical_alerts,
                }
            )

        # Add warning alerts group to validator rules
        if warning_alerts:
            validator_rules["groups"].append(
                {
                    "name": f"sui_validator_warning_alerts_{alias.replace(' ', '_')}",
                    "rules": warning_alerts,
                }
            )

        # Write validator-specific alert rules file
        try:
            with open(validator_file, "w") as f:
                yaml.dump(validator_rules, f, default_flow_style=False, sort_keys=False)
            print(
                f"Generated validator-specific alert rules: {validator_file}",
                file=sys.stderr,
            )
        except Exception as e:
            print(
                f"ERROR: Failed to write validator alert rules for {alias}: {e}",
                file=sys.stderr,
            )
            sys.exit(1)


def generate_prometheus_config(
    bridges: List[Dict[str, Any]], validators: List[Dict[str, Any]], output_file: str
) -> None:
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
                        "alias": alias,
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
                        "alias": alias,
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
                        "alias": alias,
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

    # Add validator scrape configs
    for validator in validators:
        alias = validator["alias"]
        target = validator["target"]

        # Sanitize target for scheme detection
        scheme = "http"
        clean_target = target
        if target.startswith("https://"):
            scheme = "https"
            clean_target = target[8:]
        elif target.startswith("http://"):
            scheme = "http"
            clean_target = target[7:]

        # Validator metrics scrape config
        validator_job = {
            "job_name": f'sui_validator_{alias.lower().replace(" ", "_")}',
            "static_configs": [
                {
                    "targets": [clean_target],
                    "labels": {
                        "service": "sui_validator",
                        "alias": alias,
                        "configured": "true",
                    },
                }
            ],
            "scrape_interval": "15s",
            "metrics_path": "/metrics",
            "scrape_timeout": "10s",
            "scheme": scheme,
            "honor_labels": True,
        }
        prometheus_config["scrape_configs"].append(validator_job)

    # Write configuration file
    try:
        with open(output_file, "w") as f:
            yaml.dump(prometheus_config, f, default_flow_style=False, sort_keys=False)
        print(f"Generated Prometheus configuration: {output_file}", file=sys.stderr)
    except Exception as e:
        print(f"ERROR: Failed to write Prometheus config: {e}", file=sys.stderr)
        sys.exit(1)


def generate_alertmanager_config(config: Dict[str, Any], output_file: str) -> None:
    """Generate Alertmanager configuration file with dynamic notification receivers."""

    # Get notification configurations
    pagerduty_key = config.get("pagerduty", {}).get("integration_key", "")
    telegram_bot_token = config.get("telegram", {}).get("bot_token", "")
    telegram_chat_id = config.get("telegram", {}).get("chat_id", "")
    discord_webhook_url = config.get("discord", {}).get("webhook_url", "")
    webhook_port = config.get("alertmanager", {}).get("default_webhook_port", "3001")

    # Check which notification services are configured
    has_pagerduty = bool(pagerduty_key)
    has_telegram = bool(telegram_bot_token and telegram_chat_id)
    has_discord = bool(discord_webhook_url)

    # Base alertmanager configuration
    alertmanager_config = {
        "global": {
            "resolve_timeout": "5m",
            "smtp_smarthost": "localhost:587",
            "smtp_from": "alertmanager@example.com",
        },
        "route": {
            "group_by": ["alertname", "service", "environment"],
            "group_wait": "10s",
            "group_interval": "5m",
            "repeat_interval": "3h",
            "receiver": "default",
            "routes": [
                {
                    "match": {"severity": "critical"},
                    "receiver": "critical",
                    "group_wait": "5s",
                    "repeat_interval": "1h",
                },
                {
                    "match": {"severity": "warning"},
                    "receiver": "warning",
                    "group_wait": "30s",
                    "repeat_interval": "6h",
                },
            ],
        },
        "receivers": [
            {
                "name": "default",
                "webhook_configs": [
                    {"url": f"http://localhost:{webhook_port}", "send_resolved": True}
                ],
            }
        ],
        "inhibit_rules": [
            {
                "source_match": {"severity": "critical"},
                "target_match": {"severity": "warning"},
                "equal": ["alertname", "service", "environment"],
            }
        ],
    }

    # Build critical receiver
    critical_receiver = {
        "name": "critical",
        "webhook_configs": [
            {"url": f"http://localhost:{webhook_port}", "send_resolved": True}
        ],
    }

    if has_pagerduty:
        critical_receiver["pagerduty_configs"] = [
            {
                "service_key": pagerduty_key,
                "send_resolved": True,
                "description": "{{ .GroupLabels.alertname }} - {{ .CommonAnnotations.summary }}",
                "severity": "{{ .CommonLabels.severity }}",
            }
        ]

    if has_telegram:
        critical_receiver["telegram_configs"] = [
            {
                "api_url": "https://api.telegram.org",
                "bot_token": telegram_bot_token,
                "chat_id": int(telegram_chat_id),
                "send_resolved": True,
                "parse_mode": "HTML",
                "message": "<b>🚨 CRITICAL Alert</b>\n<b>Alert:</b> {{ .GroupLabels.alertname }}\n<b>Severity:</b> {{ .CommonLabels.severity }}\n<b>Summary:</b> {{ .CommonAnnotations.summary }}\n<b>Description:</b> {{ .CommonAnnotations.description }}",
            }
        ]

    if has_discord:
        critical_receiver["discord_configs"] = [
            {
                "webhook_url": discord_webhook_url,
                "send_resolved": True,
                "title": "🚨 {{ .GroupLabels.alertname }}",
                "message": "**Severity:** {{ .CommonLabels.severity }}\n**Summary:** {{ .CommonAnnotations.summary }}\n**Description:** {{ .CommonAnnotations.description }}",
            }
        ]

    # Build warning receiver
    warning_receiver = {
        "name": "warning",
        "webhook_configs": [
            {"url": f"http://localhost:{webhook_port}", "send_resolved": True}
        ],
    }

    if has_telegram:
        warning_receiver["telegram_configs"] = [
            {
                "api_url": "https://api.telegram.org",
                "bot_token": telegram_bot_token,
                "chat_id": int(telegram_chat_id),
                "send_resolved": True,
                "parse_mode": "HTML",
                "message": "<b>⚠️ WARNING Alert</b>\n<b>Alert:</b> {{ .GroupLabels.alertname }}\n<b>Severity:</b> {{ .CommonLabels.severity }}\n<b>Summary:</b> {{ .CommonAnnotations.summary }}\n<b>Description:</b> {{ .CommonAnnotations.description }}",
            }
        ]

    if has_discord:
        warning_receiver["discord_configs"] = [
            {
                "webhook_url": discord_webhook_url,
                "send_resolved": True,
                "title": "⚠️ {{ .GroupLabels.alertname }}",
                "message": "**Severity:** {{ .CommonLabels.severity }}\n**Summary:** {{ .CommonAnnotations.summary }}\n**Description:** {{ .CommonAnnotations.description }}",
            }
        ]

    # Add receivers to config
    alertmanager_config["receivers"].append(critical_receiver)
    alertmanager_config["receivers"].append(warning_receiver)

    # Write configuration file
    try:
        with open(output_file, "w") as f:
            yaml.dump(alertmanager_config, f, default_flow_style=False, sort_keys=False)

        # Log which notification services are configured
        notification_services = []
        if has_pagerduty:
            notification_services.append("PagerDuty")
        if has_telegram:
            notification_services.append("Telegram")
        if has_discord:
            notification_services.append("Discord")

        if notification_services:
            print(
                f"Generated Alertmanager configuration with: {', '.join(notification_services)}",
                file=sys.stderr,
            )
        else:
            print(
                "Generated Alertmanager configuration (webhook only)", file=sys.stderr
            )
    except Exception as e:
        print(f"ERROR: Failed to write Alertmanager config: {e}", file=sys.stderr)
        sys.exit(1)


def export_validator_variables(validators: List[Dict[str, Any]]) -> None:
    """Export validator configuration as shell environment variables."""
    print("# Validator configuration variables")
    print(f"export SUI_VALIDATORS_COUNT={len(validators)}")

    for i, validator in enumerate(validators):
        alias = validator["alias"]
        target = validator["target"]

        # Export individual validator variables
        print(f"export SUI_VALIDATOR_{i}_ALIAS='{alias}'")
        print(f"export SUI_VALIDATOR_{i}_TARGET='{target}'")

    # Export as JSON for complex parsing - write to separate file to avoid shell parsing issues
    validators_json = json.dumps(validators, indent=2)
    print(f"export SUI_VALIDATORS_CONFIG_FILE='generated_configs/validators.json'")

    # Write JSON to file
    with open("generated_configs/validators.json", "w") as f:
        f.write(validators_json)


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
            "Usage: parse_config.py <config.yml> <prometheus_output.yml> <alert_rules_dir>",
            file=sys.stderr,
        )
        sys.exit(1)

    config_file = sys.argv[1]
    prometheus_file = sys.argv[2]
    alert_rules_dir = sys.argv[3]

    # Load configuration
    config = load_config(config_file)

    # Validate bridges configuration
    if "bridges" not in config:
        print("ERROR: No 'bridges' section found in configuration", file=sys.stderr)
        sys.exit(1)

    bridges = config["bridges"]
    validate_bridges_config(bridges)

    # Validate validators configuration (optional)
    validators = config.get("validators", [])
    if validators:
        validate_validators_config(validators)

    # Get SUI_VALIDATOR from config
    sui_validator = config.get("sui", {}).get("validator", "")

    # Generate Prometheus configuration
    generate_prometheus_config(bridges, validators, prometheus_file)

    # Generate bridge-specific alert rules
    generate_alert_rules(bridges, alert_rules_dir)

    # Generate validator-specific alert rules if validators are configured
    if validators:
        generate_validator_alert_rules(validators, sui_validator, alert_rules_dir)

    # Generate Alertmanager configuration
    alertmanager_file = "generated_configs/alertmanager.yml"
    generate_alertmanager_config(config, alertmanager_file)

    # Export bridge variables
    export_bridge_variables(bridges, sui_validator)

    # Export validator variables if configured
    if validators:
        export_validator_variables(validators)

    print(f"Successfully parsed {len(bridges)} bridge(s)", file=sys.stderr)
    if validators:
        print(f"Successfully parsed {len(validators)} validator(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
