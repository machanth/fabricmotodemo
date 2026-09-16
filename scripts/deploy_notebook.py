#!/usr/bin/env python3
"""Deploy the medallion notebook through the official Fabric ipynb definition API."""

from __future__ import annotations

import argparse
import base64
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

from deploy_items import get_credential

FABRIC_SCOPE = "https://api.fabric.microsoft.com/.default"
FABRIC_API = "https://api.fabric.microsoft.com/v1"


def source_code(path: Path) -> str:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    ignored = ("# Fabric notebook source", "# METADATA ", "# META", "# CELL ")
    return "\n".join(line for line in lines if not line.startswith(ignored)).strip() + "\n"


def request(token: str, url: str, method: str = "GET", body: object | None = None):
    data = None if body is None else json.dumps(body).encode()
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    try:
        with urllib.request.urlopen(
            urllib.request.Request(url, data=data, headers=headers, method=method),
            timeout=180,
        ) as response:
            content = response.read()
            return response.status, dict(response.headers), json.loads(content) if content else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise RuntimeError(f"Fabric API {method} {url} failed ({error.code}): {detail}") from error


def wait_for_operation(token: str, headers: dict[str, str]) -> None:
    location = headers.get("Location")
    if not location:
        return
    delay = int(headers.get("Retry-After", "10"))
    for _ in range(60):
        time.sleep(delay)
        _, _, operation = request(token, location)
        if operation["status"] == "Succeeded":
            return
        if operation["status"] == "Failed":
            raise RuntimeError(f"Fabric operation failed: {operation}")
    raise TimeoutError(f"Fabric operation did not finish: {location}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace-id", required=True)
    parser.add_argument("--lakehouse-id", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--platform", type=Path, required=True)
    args = parser.parse_args()

    code = source_code(args.source)
    wrapped = (
        "try:\n"
        + "".join(f"    {line}\n" for line in code.splitlines())
        + "except Exception:\n"
        + "    import traceback\n"
        + '    notebookutils.fs.put("Files/diagnostics/transform-error.txt", traceback.format_exc(), True)\n'
        + "    raise\n"
    )
    notebook = {
        "nbformat": 4,
        "nbformat_minor": 5,
        "cells": [
            {
                "cell_type": "code",
                "source": wrapped.splitlines(keepends=True),
                "execution_count": None,
                "outputs": [],
                "metadata": {},
            }
        ],
        "metadata": {
            "kernel_info": {"name": "synapse_pyspark"},
            "language_info": {"name": "python"},
            "dependencies": {
                "lakehouse": {
                    "default_lakehouse": args.lakehouse_id,
                    "default_lakehouse_name": "MedallionLakehouse",
                    "default_lakehouse_workspace_id": args.workspace_id,
                    "known_lakehouses": [{"id": args.lakehouse_id}],
                }
            },
        },
    }
    parts = [
        {
            "path": "artifact.content.ipynb",
            "payload": base64.b64encode(json.dumps(notebook).encode()).decode(),
            "payloadType": "InlineBase64",
        },
        {
            "path": ".platform",
            "payload": base64.b64encode(args.platform.read_bytes()).decode(),
            "payloadType": "InlineBase64",
        },
    ]

    token = get_credential().get_token(FABRIC_SCOPE).token
    items_url = f"{FABRIC_API}/workspaces/{args.workspace_id}/items"
    _, _, listed = request(token, f"{items_url}?type=Notebook")
    matches = [item for item in listed["value"] if item["displayName"] == "TransformMedallion"]
    if len(matches) > 1:
        raise RuntimeError("More than one Notebook is named TransformMedallion.")

    if matches:
        item = matches[0]
        status, headers, _ = request(
            token,
            f"{items_url}/{item['id']}/updateDefinition?updateMetadata=true",
            "POST",
            {"definition": {"format": "ipynb", "parts": parts}},
        )
    else:
        status, headers, item = request(
            token,
            items_url,
            "POST",
            {
                "displayName": "TransformMedallion",
                "type": "Notebook",
                "description": "Idempotent medallion transformation for the synthetic POC.",
                "definition": {"format": "ipynb", "parts": parts},
            },
        )
    if status == 202:
        wait_for_operation(token, headers)
        _, _, listed = request(token, f"{items_url}?type=Notebook")
        item = next(value for value in listed["value"] if value["displayName"] == "TransformMedallion")
    print(json.dumps({"id": item["id"], "displayName": item["displayName"], "type": item["type"]}))


if __name__ == "__main__":
    main()
