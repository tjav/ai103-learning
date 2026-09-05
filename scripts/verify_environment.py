"""AI-103 Katas — environment verification.

Checks that every prerequisite the labs depend on is present and reachable.
Run after the provisioning scripts, and any time a notebook misbehaves.

    python scripts/verify_environment.py
    python scripts/verify_environment.py --unit 05.1   # check one unit's prereqs
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

GREEN, YELLOW, RED, DIM, RESET = "\033[92m", "\033[93m", "\033[91m", "\033[2m", "\033[0m"
if os.name == "nt" and not os.environ.get("WT_SESSION"):
    try:
        import colorama  # type: ignore

        colorama.just_fix_windows_console()
    except Exception:
        GREEN = YELLOW = RED = DIM = RESET = ""

results: list[tuple[str, str, str]] = []  # (status, label, detail)


def ok(label: str, detail: str = "") -> None:
    results.append(("ok", label, detail))
    print(f"  {GREEN}[ok]{RESET}   {label}" + (f" {DIM}{detail}{RESET}" if detail else ""))


def warn(label: str, detail: str = "") -> None:
    results.append(("warn", label, detail))
    print(f"  {YELLOW}[warn]{RESET} {label}" + (f" {DIM}{detail}{RESET}" if detail else ""))


def fail(label: str, detail: str = "") -> None:
    results.append(("fail", label, detail))
    print(f"  {RED}[fail]{RESET} {label}" + (f" {DIM}{detail}{RESET}" if detail else ""))


def section(title: str) -> None:
    print(f"\n=== {title} ===")


# ---------------------------------------------------------------------------
# 1. Python and packages
# ---------------------------------------------------------------------------
def check_python() -> None:
    section("Python")

    major, minor = sys.version_info[:2]
    if (3, 10) <= (major, minor) <= (3, 12):
        ok(f"Python {major}.{minor}")
    else:
        warn(f"Python {major}.{minor}", "3.10-3.12 recommended; some SDKs lag on newer versions")

    packages = {
        "azure.identity": "azure-identity",
        "azure.ai.projects": "azure-ai-projects",
        "azure.ai.agents": "azure-ai-agents",
        "openai": "openai",
        "azure.search.documents": "azure-search-documents",
        "azure.storage.blob": "azure-storage-blob",
        "azure.ai.evaluation": "azure-ai-evaluation",
        "azure.ai.textanalytics": "azure-ai-textanalytics",
        "azure.ai.contentsafety": "azure-ai-contentsafety",
        "dotenv": "python-dotenv",
    }
    missing = []
    for module, dist in packages.items():
        try:
            __import__(module)
        except ImportError:
            missing.append(dist)

    if missing:
        fail(f"{len(missing)} package(s) missing", "pip install -r requirements.txt")
        for dist in missing:
            print(f"         - {dist}")
    else:
        ok(f"all {len(packages)} required packages importable")


# ---------------------------------------------------------------------------
# 2. .env
# ---------------------------------------------------------------------------
REQUIRED_VARS = [
    "AZURE_TENANT_ID",
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_RESOURCE_GROUP",
    "AZURE_LOCATION",
    "AZURE_AI_FOUNDRY_RESOURCE",
    "AZURE_AI_PROJECT_ENDPOINT",
    "AZURE_OPENAI_ENDPOINT",
    "MODEL_CHAT",
    "MODEL_MINI",
    "MODEL_EMBEDDING",
]

OPTIONAL_VARS = [
    "AZURE_SEARCH_ENDPOINT",
    "AZURE_STORAGE_ACCOUNT",
    "APPLICATIONINSIGHTS_CONNECTION_STRING",
    "AZURE_SPEECH_KEY",
]


def check_env() -> dict[str, str]:
    section(".env")

    env_path = ROOT / ".env"
    if not env_path.exists():
        fail(".env not found", "run: pwsh scripts/01_connect_azure.ps1")
        return {}

    try:
        from dotenv import dotenv_values

        cfg = {k: v for k, v in dotenv_values(env_path).items() if v}
    except ImportError:
        cfg = {}
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                if v.strip():
                    cfg[k.strip()] = v.strip()

    os.environ.update(cfg)

    missing = [v for v in REQUIRED_VARS if not cfg.get(v)]
    if missing:
        fail(f"{len(missing)} required variable(s) empty", ", ".join(missing))
    else:
        ok(f"all {len(REQUIRED_VARS)} required variables set")

    for var in OPTIONAL_VARS:
        if not cfg.get(var):
            warn(f"{var} not set", "the unit that needs it will tell you")

    return cfg


# ---------------------------------------------------------------------------
# 3. Azure credential
# ---------------------------------------------------------------------------
def check_credential(cfg: dict[str, str]):
    section("Azure credential")

    try:
        from azure.identity import DefaultAzureCredential
    except ImportError:
        fail("azure-identity not installed")
        return None

    try:
        cred = DefaultAzureCredential(exclude_interactive_browser_credential=False)
        token = cred.get_token("https://management.azure.com/.default")
        ok("DefaultAzureCredential", f"token expires {token.expires_on}")
        return cred
    except Exception as exc:  # noqa: BLE001
        fail("DefaultAzureCredential", f"{type(exc).__name__}: {exc}")
        print(f"         {DIM}Fix: run `az login --tenant {cfg.get('AZURE_TENANT_ID', '<tenant>')}`{RESET}")
        return None


# ---------------------------------------------------------------------------
# 4. Foundry project + model deployments
# ---------------------------------------------------------------------------
def check_foundry(cfg: dict[str, str], cred) -> None:
    section("Foundry project")

    endpoint = cfg.get("AZURE_AI_PROJECT_ENDPOINT")
    if not endpoint or cred is None:
        warn("skipped", "missing endpoint or credential")
        return

    try:
        from azure.ai.projects import AIProjectClient

        client = AIProjectClient(endpoint=endpoint, credential=cred)
        ok("AIProjectClient connected", endpoint)
    except Exception as exc:  # noqa: BLE001
        fail("AIProjectClient", f"{type(exc).__name__}: {exc}")
        print(f"         {DIM}Check the project exists and you hold the 'Azure AI User' role.{RESET}")
        return

    # Model deployments — the labs address models by deployment name.
    wanted = {
        "MODEL_MINI": "most labs",
        "MODEL_CHAT": "vision + agent labs",
        "MODEL_EMBEDDING": "units 02.2, 05.1",
        "MODEL_REASONING": "unit 02.5",
    }
    try:
        found = {d.name for d in client.deployments.list()}
        ok(f"{len(found)} deployment(s) found", ", ".join(sorted(found)) or "none")
        for var, why in wanted.items():
            name = cfg.get(var)
            if not name:
                continue
            if name in found:
                ok(f"deployment '{name}'", why)
            else:
                warn(f"deployment '{name}' missing", f"needed for {why}")
    except Exception as exc:  # noqa: BLE001
        warn("could not list deployments", f"{type(exc).__name__}: {exc}")


# ---------------------------------------------------------------------------
# 5. Inference smoke test
# ---------------------------------------------------------------------------
def check_inference(cfg: dict[str, str], cred) -> None:
    section("Inference smoke test")

    if cred is None:
        warn("skipped", "no credential")
        return

    endpoint = cfg.get("AZURE_OPENAI_ENDPOINT")
    model = cfg.get("MODEL_MINI")
    if not endpoint or not model:
        warn("skipped", "AZURE_OPENAI_ENDPOINT or MODEL_MINI not set")
        return

    try:
        from azure.identity import get_bearer_token_provider
        from openai import AzureOpenAI

        client = AzureOpenAI(
            azure_endpoint=endpoint,
            api_version=cfg.get("AZURE_OPENAI_API_VERSION", "2025-04-01-preview"),
            azure_ad_token_provider=get_bearer_token_provider(
                cred, "https://cognitiveservices.azure.com/.default"
            ),
        )
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": "Reply with exactly: ready"}],
            max_completion_tokens=10,
        )
        text = (resp.choices[0].message.content or "").strip()
        ok(f"chat completion via '{model}'", f"model replied: {text!r}")
    except Exception as exc:  # noqa: BLE001
        fail("chat completion", f"{type(exc).__name__}: {exc}")
        print(f"         {DIM}Common causes: deployment not ready, quota=0, or missing")
        print(f"         'Cognitive Services OpenAI User' role on the Foundry resource.{RESET}")


# ---------------------------------------------------------------------------
# 6. Search and Storage
# ---------------------------------------------------------------------------
def check_search(cfg: dict[str, str], cred) -> None:
    section("Azure AI Search")

    endpoint = cfg.get("AZURE_SEARCH_ENDPOINT")
    if not endpoint or cred is None:
        warn("skipped", "not provisioned — units 02.2 and 05.1 need it")
        return

    try:
        from azure.search.documents.indexes import SearchIndexClient

        client = SearchIndexClient(endpoint=endpoint, credential=cred)
        names = [i.name for i in client.list_indexes()]
        ok("SearchIndexClient connected", f"{len(names)} index(es): {', '.join(names) or 'none yet'}")
    except Exception as exc:  # noqa: BLE001
        fail("SearchIndexClient", f"{type(exc).__name__}: {exc}")
        print(f"         {DIM}Needs the 'Search Index Data Contributor' role and RBAC auth enabled.{RESET}")


def check_storage(cfg: dict[str, str], cred) -> None:
    section("Storage")

    account = cfg.get("AZURE_STORAGE_ACCOUNT")
    if not account or cred is None:
        warn("skipped", "not provisioned")
        return

    try:
        from azure.storage.blob import BlobServiceClient

        client = BlobServiceClient(f"https://{account}.blob.core.windows.net", credential=cred)
        names = [c.name for c in client.list_containers()]
        ok("BlobServiceClient connected", f"containers: {', '.join(names) or 'none'}")
    except Exception as exc:  # noqa: BLE001
        fail("BlobServiceClient", f"{type(exc).__name__}: {exc}")
        print(f"         {DIM}Needs the 'Storage Blob Data Contributor' role.{RESET}")


# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description="Verify the AI-103 lab environment.")
    parser.add_argument("--skip-inference", action="store_true", help="do not call a model (avoids token cost)")
    args = parser.parse_args()

    print("AI-103 Katas — environment check")

    check_python()
    cfg = check_env()
    cred = check_credential(cfg) if cfg else None

    if cfg:
        check_foundry(cfg, cred)
        if not args.skip_inference:
            check_inference(cfg, cred)
        check_search(cfg, cred)
        check_storage(cfg, cred)

    fails = sum(1 for s, _, _ in results if s == "fail")
    warns = sum(1 for s, _, _ in results if s == "warn")
    oks = sum(1 for s, _, _ in results if s == "ok")

    print(f"\n{'-' * 60}")
    print(f"{oks} ok · {warns} warning · {fails} failed")

    if fails:
        print(f"\n{RED}Not ready.{RESET} Fix the failures above, then re-run.")
        return 1
    if warns:
        print(f"\n{YELLOW}Ready, with gaps.{RESET} Warnings only block the specific units named above.")
        return 0

    print(f"\n{GREEN}Ready.{RESET} Open 00_setup/README.md.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
