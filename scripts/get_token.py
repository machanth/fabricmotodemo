#!/usr/bin/env python3
"""Acquire an Azure token without printing credential material."""

from __future__ import annotations

import os
import sys

from azure.identity import AzureCliCredential, ClientSecretCredential


def credential():
    values = [
        os.environ.get("AZURE_TENANT_ID"),
        os.environ.get("AZURE_CLIENT_ID"),
        os.environ.get("AZURE_CLIENT_SECRET"),
    ]
    if all(values):
        return ClientSecretCredential(*values)
    return AzureCliCredential()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: get_token.py SCOPE")
    print(credential().get_token(sys.argv[1]).token)
