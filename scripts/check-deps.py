#!/usr/bin/env python3
"""Report upstream dependency updates without modifying project locks."""

import argparse
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import xml.etree.ElementTree as ET


TIMEOUT = 20


def origin(url):
    parsed = urlsplit(url)
    port = parsed.port if parsed.port is not None else {"https": 443, "http": 80}.get(parsed.scheme)
    return parsed.scheme, parsed.hostname, port


class OriginSafeRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        redirected = super().redirect_request(request, response, code, message, headers, new_url)
        if redirected is not None and origin(request.full_url) != origin(redirected.full_url):
            redirected.remove_header("Authorization")
        return redirected


OPENER = build_opener(OriginSafeRedirectHandler())


def fetch(url, accept="application/json"):
    headers = {"Accept": accept, "User-Agent": "project-dependency-check/1"}
    if origin(url) == ("https", "api.github.com", 443):
        token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        if token:
            headers["Authorization"] = "Bearer " + token
    try:
        with OPENER.open(Request(url, headers=headers), timeout=TIMEOUT) as response:
            return response.read()
    except HTTPError as error:
        raise ValueError(f"upstream HTTP {error.code}") from error
    except (URLError, OSError, TimeoutError) as error:
        raise ValueError("upstream request unavailable: " + str(error.reason if isinstance(error, URLError) else error)) from error


def fetch_json(url):
    payload = json.loads(fetch(url))
    if not isinstance(payload, dict):
        raise ValueError("upstream JSON must be an object")
    return payload


def public_url(entry):
    url = required(entry, "url")
    parsed = urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("metadata requires a public HTTPS URL")
    return url


def stable_key(version):
    # Numeric stable releases, PEP 440 epochs/posts and Maven final aliases.
    match = re.fullmatch(
        r"v?(?:(\d+)!)?(\d+(?:\.\d+)*)(?:(?:[._-]?(?:post|rev|r))(\d*)|-(\d+))?"
        r"(?:[._-](?:final|release|ga))?(?:\+[a-z0-9]+(?:[._-][a-z0-9]+)*)?",
        version, re.IGNORECASE)
    if match is None:
        return None
    numbers = list(map(int, match[2].split(".")))
    while len(numbers) > 1 and numbers[-1] == 0:
        numbers.pop()
    post = match[3] if match[3] is not None else match[4]
    return int(match[1] or 0), tuple(numbers), -1 if post is None else int(post or 0)


def required(entry, field):
    value = entry.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"missing nonempty {field}")
    return value


def github_repository(entry):
    repository = required(entry, "repository")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("repository must be OWNER/REPO")
    return "https://api.github.com/repos/" + repository


def latest(entry):
    kind = required(entry, "kind")
    current = required(entry, "current")
    if kind == "github-release":
        base = github_repository(entry)
        release = fetch_json(base + "/releases/latest")
        if release.get("draft") is not False or release.get("prerelease") is not False:
            raise ValueError("upstream did not return a stable published release")
        tag = required(release, "tag_name")
        if re.fullmatch(r"[0-9a-f]{40}", current):
            revision = required(fetch_json(base + "/commits/" + quote(tag, safe="")), "sha")
            if not re.fullmatch(r"[0-9a-f]{40}", revision):
                raise ValueError("upstream release revision is not a full SHA")
            return revision, tag
        return tag, tag
    if kind == "github-revision":
        ref = required(entry, "ref")
        revision = required(fetch_json(github_repository(entry) + "/commits/" + quote(ref, safe="")), "sha")
        if not re.fullmatch(r"[0-9a-f]{40}", current) or not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError("source revisions must be full lowercase SHAs")
        return revision, revision
    if kind == "pypi":
        package = required(entry, "package")
        payload = fetch_json("https://pypi.org/pypi/" + quote(package, safe="") + "/json")
        releases = payload.get("releases")
        if not isinstance(releases, dict) or any(
                not isinstance(files, list) or any(not isinstance(file, dict) for file in files)
                for files in releases.values()):
            raise ValueError("PyPI releases must map versions to lists of file objects")
        choices = [(stable_key(version), version) for version, files in releases.items()
                   if stable_key(version) is not None and any(not file.get("yanked", False) for file in files)]
        if not choices:
            raise ValueError("upstream has no supported stable non-yanked release")
        version = max(choices)[1]
        return version, version
    if kind == "nodejs":
        releases = json.loads(fetch("https://nodejs.org/dist/index.json"))
        if not isinstance(releases, list) or any(not isinstance(row, dict) for row in releases):
            raise ValueError("invalid Node.js release index")
        versions = [required(row, "version") for row in releases]
        stable = [v for v in versions if re.fullmatch(r"v\d+\.\d+\.\d+", v)]
        if not stable:
            raise ValueError("no stable Node.js release in index")
        version = max(stable, key=stable_key)
        return version, version
    if kind == "npm":
        package = required(entry, "package")
        payload = fetch_json("https://registry.npmjs.org/" + quote(package, safe="") + "/latest")
        version = required(payload, "version")
        if not re.fullmatch(r"v?\d+\.\d+\.\d+(?:\+[A-Za-z0-9.-]+)?", version):
            raise ValueError("npm latest is not a supported stable release")
        return version, version
    if kind == "json-version":
        path = entry.get("path")
        if not isinstance(path, list) or not path or any(not isinstance(key, str) or not key for key in path):
            raise ValueError("JSON version path must be a nonempty object-key array")
        value = fetch_json(public_url(entry))
        for key in path:
            if not isinstance(value, dict) or key not in value:
                raise ValueError("JSON version path is missing")
            value = value[key]
        if not isinstance(value, str) or stable_key(value) is None:
            raise ValueError("JSON version value is not a supported stable version string")
        return value, value
    if kind == "maven":
        url = public_url(entry)
        metadata = ET.fromstring(fetch(url, "application/xml"))
        versions = [node.text.strip() for node in metadata.findall("./versioning/versions/version") if node.text]
        release = metadata.findtext("./versioning/release")
        if release:
            versions.append(release.strip())
        choices = [(stable_key(version), version) for version in versions if stable_key(version) is not None]
        if not choices:
            raise ValueError("Maven metadata has no supported stable release")
        version = max(choices)[1]
        return version, version
    raise ValueError("unsupported update source kind: " + kind)


def check(metadata):
    if type(metadata.get("schema")) is not int or metadata["schema"] != 1 or not isinstance(metadata.get("dependencies"), list) or not metadata["dependencies"]:
        raise ValueError("expected schema 1 with a nonempty dependencies list")
    results, names = [], set()
    for entry in metadata["dependencies"]:
        name = "<invalid dependency>"
        try:
            if not isinstance(entry, dict):
                raise ValueError("dependency must be an object")
            name, current = required(entry, "name"), required(entry, "current")
            if name in names:
                raise ValueError("duplicate dependency name")
            names.add(name)
            candidate, label = latest(entry)
            status = "current" if (current[1:] if current.startswith("v") else current) == (candidate[1:] if candidate.startswith("v") else candidate) else "available"
            old_key, new_key = stable_key(current), stable_key(candidate)
            if entry["kind"] == "github-revision" or re.fullmatch(r"[0-9a-f]{40}", current):
                old_key = new_key = None
            if old_key is not None and new_key is not None:
                status = "available" if new_key > old_key else "ahead" if new_key < old_key else "current"
            results.append({"name": name, "current": current, "latest": candidate,
                            "upstream": label, "status": status})
        except (ValueError, TypeError, KeyError, ET.ParseError) as error:
            results.append({"name": name, "status": "error", "error": str(error)})
    return results


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print machine-readable check results")
    parser.add_argument("--metadata-stdin", action="store_true",
                        help="read evaluated dependency metadata from stdin without a development environment")
    args = parser.parse_args(argv)
    try:
        if args.metadata_stdin:
            metadata = json.load(sys.stdin)
        else:
            environment = os.environ.get("PROJECT_NIX_ENVIRONMENT")
            if not environment or not Path(environment).is_absolute():
                raise ValueError("use scripts/check-deps, --metadata-stdin, or a realized project environment")
            metadata = json.loads((Path(environment) / "share" / "dependency-updates.json").read_text(encoding="utf-8"))
        if not isinstance(metadata, dict):
            raise ValueError("dependency metadata must be an object")
        results = check(metadata)
    except (OSError, ValueError, TypeError) as error:
        print("dependency check failed: " + str(error), file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps({"schema": 1, "dependencies": results}, indent=2))
    else:
        for result in results:
            if result["status"] == "error":
                print(f"ERROR {result['name']}: {result['error']}", file=sys.stderr)
            else:
                print(f"{result['status'].upper()} {result['name']}: locked {result['current']}; upstream {result['upstream']}")
    return 2 if any(result["status"] == "error" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
