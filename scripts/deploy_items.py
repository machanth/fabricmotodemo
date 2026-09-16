#!/usr/bin/env python3
"""Deploy supported Fabric item definitions through Microsoft's fabric-cicd library."""

from __future__ import annotations

import argparse
from pathlib import Path

import os

from azure.identity import AzureCliCredential, ClientSecretCredential
from fabric_cicd import FabricWorkspace, publish_all_items


def get_credential():
    values = [
        os.environ.get("AZURE_TENANT_ID"),
        os.environ.get("AZURE_CLIENT_ID"),
        os.environ.get("AZURE_CLIENT_SECRET"),
    ]
    if all(values):
        return ClientSecretCredential(*values)
    return AzureCliCredential()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace-id", required=True)
    parser.add_argument("--repository-directory", type=Path, required=True)
    parser.add_argument("--environment", default="POC")
    parser.add_argument("--item-types", nargs="+", required=True)
    args = parser.parse_args()

    workspace = FabricWorkspace(
        workspace_id=args.workspace_id,
        environment=args.environment,
        repository_directory=str(args.repository_directory.resolve()),
        item_type_in_scope=args.item_types,
        token_credential=get_credential(),
    )
    publish_all_items(workspace)


if __name__ == "__main__":
    main()
