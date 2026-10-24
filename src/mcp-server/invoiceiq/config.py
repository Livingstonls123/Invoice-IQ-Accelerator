"""Runtime configuration from environment variables (App Service app settings)."""
from __future__ import annotations

import os
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Settings:
    # Azure AI Document Intelligence (managed identity auth)
    docintel_endpoint: str = field(default_factory=lambda: os.getenv("DOCINTEL_ENDPOINT", ""))
    docintel_model: str = field(default_factory=lambda: os.getenv("DOCINTEL_MODEL", "prebuilt-invoice"))

    # Storage account that receives invoices. URLs on this account WITHOUT a SAS token are
    # downloaded by the server with its managed identity; SAS URLs are passed straight to
    # Document Intelligence.
    storage_account_url: str = field(default_factory=lambda: os.getenv("STORAGE_ACCOUNT_URL", ""))

    # Hosts the tool will accept document URLs from (comma-separated, wildcards allowed)
    allowed_hosts: str = field(default_factory=lambda: os.getenv("ALLOWED_DOCUMENT_HOSTS", "*.blob.core.windows.net"))

    # MCP endpoint protection: Copilot Studio sends this as an API key header
    api_key: str = field(default_factory=lambda: os.getenv("MCP_API_KEY", ""))
    api_key_header: str = field(default_factory=lambda: os.getenv("MCP_API_KEY_HEADER", "x-api-key"))

    # Value written when a field is not found (matches the agent instructions)
    missing_value: str = field(default_factory=lambda: os.getenv("MISSING_VALUE", "NA"))


def get_settings() -> Settings:
    return Settings()
