#!/usr/bin/env python3
"""Validate the JS result and native HTTP traffic from a runtime check."""

import argparse
import json
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_json_lines(path: Path):
    if not path.is_file():
        return []
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.strip()
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--requests-file", required=True)
    parser.add_argument("--expected-wrapper-version", required=True)
    args = parser.parse_args()

    requests = load_json_lines(Path(args.requests_file))
    require(requests, "recording backend received no native SDK requests")
    result_entries = [
        item.get("body")
        for item in requests
        if item.get("path", "").split("?", 1)[0] == "/runtime-result"
        and item.get("body")
    ]
    require(result_entries, "recording backend received no terminal validation result")
    terminal = result_entries[-1]
    require(
        terminal.get("kind") == "success",
        f"runtime probe reported an error: {terminal.get('payload')}",
    )
    result = terminal.get("payload") or {}

    require(result.get("configured") is True, "wrapper configuration did not complete")
    require(result.get("appstackIdPresent") is True, "native SDK returned no Appstack ID")
    require(result.get("sdkDisabled") is False, "native SDK reports disabled")
    require(result.get("callbackCount") == 3, "not all attribution calls completed")
    require(result.get("successCount") == 3, "attribution calls did not all succeed")
    require(
        result.get("attributionValidated") is True,
        "attribution payload was corrupted across the bridge",
    )
    require(result.get("eventsAccepted") == 2, "wrapper did not accept both events")
    require(
        result.get("validationError") == "Either eventName or eventType must be provided",
        "wrapper did not return the expected meaningful validation error",
    )
    require(not result.get("errors"), f"runtime errors: {result.get('errors')}")

    require(
        any(item["path"].split("?", 1)[0].endswith("/config") for item in requests),
        "native SDK did not fetch remote configuration",
    )
    require(
        any("/attribution/match" in item["path"] for item in requests),
        "native SDK did not perform attribution matching",
    )

    events = [
        item["body"]
        for item in requests
        if item["path"].split("?", 1)[0].endswith("/events") and item.get("body")
    ]
    custom = next(
        (
            event
            for event in events
            if event.get("event_name") == "runtime_validation_custom"
        ),
        None,
    )
    login = next(
        (event for event in events if event.get("event_name") == "LOGIN"), None
    )
    require(custom is not None, "custom event never reached the native wire boundary")
    require(login is not None, "standard event never reached the native wire boundary")
    require(
        custom.get("wrapper_version") == args.expected_wrapper_version,
        "wrong wrapper version on event",
    )
    require(
        custom.get("customer_user_id") == "runtime-validation-user",
        "customer user ID was not forwarded",
    )

    parameters = custom.get("custom_parameters") or {}
    require(parameters.get("string") == "bridge-value", "string parameter changed")
    require(parameters.get("number") == 42, "integer parameter changed")
    require(parameters.get("decimal") == 9.75, "decimal parameter changed")
    require(parameters.get("boolean") is True, "boolean parameter changed")
    require(parameters.get("unicode") == "café 🚀", "UTF-8 parameter changed")
    require(
        parameters.get("array") == ["one", 2, False], "array parameter changed"
    )
    require(
        parameters.get("nested") == {
            "enabled": True,
            "items": ["nested", 3, False],
        },
        "nested parameters changed",
    )

    login_parameters = login.get("custom_parameters") or {}
    require(
        login_parameters.get("state") == "ready",
        "standard event string parameter changed",
    )
    require(
        login_parameters.get("sequence") == 2,
        "standard event numeric parameter changed",
    )

    print(
        json.dumps(
            {
                "platform": result.get("platform"),
                "attributionCalls": result.get("callbackCount"),
                "eventsRecorded": len(events),
                "wrapperVersion": custom.get("wrapper_version"),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, json.JSONDecodeError, OSError) as error:
        raise SystemExit(f"runtime validation failed: {error}") from None
