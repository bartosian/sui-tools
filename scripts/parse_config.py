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

        # Export individual bridge variables
        print(f"export SUI_BRIDGE_{i}_ALIAS='{alias}'")
        print(f"export SUI_BRIDGE_{i}_TARGET='{target}'")
        print(f"export SUI_BRIDGE_{i}_PUBLIC_ADDRESS='{public_address}'")

    # Export as JSON for complex parsing - write to separate file to avoid shell parsing issues
    bridges_json = json.dumps(bridges, indent=2)
    print(f"export SUI_BRIDGES_CONFIG_FILE='generated_configs/bridges.json'")

    # Write JSON to file
    with open("generated_configs/bridges.json", "w") as f:
        f.write(bridges_json)


def main():
    """Main function."""
    if len(sys.argv) != 3:
        print("Usage: parse_config.py <config.yml> <prometheus.yml>", file=sys.stderr)
        sys.exit(1)

    config_file = sys.argv[1]
    prometheus_file = sys.argv[2]

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

    # Export bridge variables
    export_bridge_variables(bridges, sui_validator)

    print(f"Successfully parsed {len(bridges)} bridge(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
