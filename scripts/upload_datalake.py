#!/usr/bin/env python3
"""Upload a local directory to ADLS Gen2 or OneLake with Entra authentication."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from azure.core.exceptions import ResourceExistsError
from azure.identity import AzureCliCredential, ClientSecretCredential
from azure.storage.filedatalake import DataLakeServiceClient


def credential():
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
    parser.add_argument("--account-url", required=True)
    parser.add_argument("--filesystem", required=True)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--create-filesystem", action="store_true")
    args = parser.parse_args()

    if not args.source.is_dir():
        parser.error(f"source directory does not exist: {args.source}")

    service = DataLakeServiceClient(args.account_url.rstrip("/"), credential=credential())
    filesystem = service.get_file_system_client(args.filesystem)
    if args.create_filesystem:
        try:
            filesystem.create_file_system()
        except ResourceExistsError:
            pass
    else:
        filesystem.get_file_system_properties()

    uploaded = []
    for source_file in sorted(path for path in args.source.rglob("*") if path.is_file()):
        relative = source_file.relative_to(args.source).as_posix()
        destination = f"{args.destination.strip('/')}/{relative}"
        file_client = filesystem.get_file_client(destination)
        with source_file.open("rb") as stream:
            file_client.upload_data(stream, overwrite=True)
        properties = file_client.get_file_properties()
        if properties.size != source_file.stat().st_size:
            raise RuntimeError(f"size verification failed for {destination}")
        uploaded.append({"path": destination, "bytes": properties.size})

    for result in uploaded:
        print(f"UPLOADED {result['path']} ({result['bytes']} bytes)")
    print(f"Verified {len(uploaded)} uploaded files.")


if __name__ == "__main__":
    main()
