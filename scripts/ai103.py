"""Shared helpers for the AI-103 lab notebooks.

Every notebook starts with:

    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path.cwd().parents[1] / "scripts"))
    from ai103 import cfg, credential, chat_client, project_client

Keeping this in one place means the labs stay about Azure AI, not about
boilerplate.
"""

from __future__ import annotations

import functools
import os
from pathlib import Path
from typing import Any

_ROOT = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
class Config(dict):
    """Dict of .env values with a helpful error when something is missing."""

    def require(self, key: str, unit: str | None = None) -> str:
        value = self.get(key)
        if not value:
            hint = f" Unit {unit} needs it." if unit else ""
            raise RuntimeError(
                f"{key} is not set in {_ROOT / '.env'}.{hint}\n"
                "Run: pwsh scripts/01_connect_azure.ps1 (then 02_ and 03_)."
            )
        return value


@functools.lru_cache(maxsize=1)
def load_config() -> Config:
    """Read ../.env into a Config and into os.environ."""
    env_path = _ROOT / ".env"
    if not env_path.exists():
        raise RuntimeError(
            f"No .env at {env_path}.\nRun: pwsh scripts/01_connect_azure.ps1"
        )

    values: dict[str, str] = {}
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        val = val.strip().strip('"').strip("'")
        if val:
            values[key.strip()] = val

    os.environ.update(values)
    return Config(values)


cfg = load_config()


# ---------------------------------------------------------------------------
# Credential
# ---------------------------------------------------------------------------
@functools.lru_cache(maxsize=1)
def credential():
    """A DefaultAzureCredential that works from `az login`.

    All labs use Microsoft Entra ID rather than API keys. That is both the
    recommended production pattern and an exam objective ("keyless credentials").
    """
    from azure.identity import DefaultAzureCredential

    return DefaultAzureCredential(
        exclude_interactive_browser_credential=False,
        # Avoid a slow probe on machines with a stale managed-identity endpoint.
        exclude_managed_identity_credential=True,
    )


def token_provider(scope: str = "https://cognitiveservices.azure.com/.default"):
    from azure.identity import get_bearer_token_provider

    return get_bearer_token_provider(credential(), scope)


# ---------------------------------------------------------------------------
# Clients
# ---------------------------------------------------------------------------
@functools.lru_cache(maxsize=1)
def project_client():
    """AIProjectClient — the control plane for a Foundry project.

    Use it to list deployments and connections, and to reach the Agents client
    via `project_client().agents`.
    """
    from azure.ai.projects import AIProjectClient

    return AIProjectClient(
        endpoint=cfg.require("AZURE_AI_PROJECT_ENDPOINT"),
        credential=credential(),
    )


@functools.lru_cache(maxsize=1)
def chat_client():
    """AzureOpenAI client bound to the Foundry resource, authenticated with Entra ID."""
    from openai import AzureOpenAI

    return AzureOpenAI(
        azure_endpoint=cfg.require("AZURE_OPENAI_ENDPOINT"),
        api_version=cfg.get("AZURE_OPENAI_API_VERSION", "2025-04-01-preview"),
        azure_ad_token_provider=token_provider(),
    )


@functools.lru_cache(maxsize=1)
def search_index_client():
    from azure.search.documents.indexes import SearchIndexClient

    return SearchIndexClient(
        endpoint=cfg.require("AZURE_SEARCH_ENDPOINT", unit="05.1"),
        credential=credential(),
    )


def search_client(index_name: str | None = None):
    from azure.search.documents import SearchClient

    return SearchClient(
        endpoint=cfg.require("AZURE_SEARCH_ENDPOINT", unit="05.1"),
        index_name=index_name or cfg.require("AZURE_SEARCH_INDEX"),
        credential=credential(),
    )


@functools.lru_cache(maxsize=1)
def blob_service_client():
    from azure.storage.blob import BlobServiceClient

    account = cfg.require("AZURE_STORAGE_ACCOUNT")
    return BlobServiceClient(
        f"https://{account}.blob.core.windows.net", credential=credential()
    )


# ---------------------------------------------------------------------------
# Convenience
# ---------------------------------------------------------------------------
def ask(prompt: str, *, model: str | None = None, system: str | None = None, **kwargs: Any) -> str:
    """One-shot chat completion. Defaults to the cheap model."""
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    resp = chat_client().chat.completions.create(
        model=model or cfg.require("MODEL_MINI"),
        messages=messages,
        **kwargs,
    )
    return resp.choices[0].message.content or ""


def embed(texts: str | list[str], *, model: str | None = None) -> list[list[float]]:
    """Embed one or more strings. Returns a list of vectors."""
    items = [texts] if isinstance(texts, str) else texts
    resp = chat_client().embeddings.create(
        model=model or cfg.require("MODEL_EMBEDDING"), input=items
    )
    return [d.embedding for d in resp.data]


def show_usage(response: Any) -> None:
    """Print token usage — you will do this constantly in unit 02.5."""
    u = getattr(response, "usage", None)
    if not u:
        print("no usage data on this response")
        return
    print(
        f"prompt={u.prompt_tokens}  completion={u.completion_tokens}  total={u.total_tokens}"
    )


def portal_link(kind: str = "project") -> str:
    """Build a deep link into the Azure or Foundry portal for the lab resources."""
    sub = cfg.get("AZURE_SUBSCRIPTION_ID", "")
    rg = cfg.get("AZURE_RESOURCE_GROUP", "")
    links = {
        "project": "https://ai.azure.com",
        "resource_group": f"https://portal.azure.com/#@/resource/subscriptions/{sub}/resourceGroups/{rg}/overview",
        "cost": f"https://portal.azure.com/#@/resource/subscriptions/{sub}/resourceGroups/{rg}/costanalysis",
        "quotas": "https://ai.azure.com/managementCenter/quota",
    }
    return links.get(kind, links["project"])


__all__ = [
    "cfg",
    "credential",
    "token_provider",
    "project_client",
    "chat_client",
    "search_index_client",
    "search_client",
    "blob_service_client",
    "ask",
    "embed",
    "show_usage",
    "portal_link",
]
