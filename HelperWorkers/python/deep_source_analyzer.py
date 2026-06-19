#!/usr/bin/env python3
import json
import re
import sys
from collections import Counter


RESERVED = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
    "until", "while", "self", "game", "workspace", "script", "local", "return",
}

SIGNALS = {
    "remote_calls": [r"\bFireServer\s*\(", r"\bInvokeServer\s*\(", r"\bOnClientEvent\b", r"\bOnClientInvoke\b"],
    "dynamic_code": [r"\bloadstring\s*\(", r"\bgetfenv\b", r"\bsetfenv\b"],
    "http": [r"\bHttpGet\b", r"\bHttpPost\b", r"\brequest\s*\("],
    "filesystem": [r"\breadfile\s*\(", r"\bwritefile\s*\(", r"\bappendfile\s*\("],
    "hooks": [r"\bhookfunction\b", r"\bhookmetamethod\b", r"\bgetrawmetatable\b"],
    "gc_debug": [r"\bgetgc\b", r"\bgetconnections\b", r"\bdebug\."],
}


def count_patterns(source, patterns):
    return sum(len(re.findall(pattern, source)) for pattern in patterns)


def top_identifiers(source, limit=16):
    words = re.findall(r"[A-Za-z_][A-Za-z0-9_]{2,}", source)
    counts = Counter(word for word in words if word.lower() not in RESERVED)
    return [{"name": name, "count": count} for name, count in counts.most_common(limit)]


def main():
    source = sys.stdin.read()
    lines = source.count("\n") + (1 if source else 0)
    functions = len(re.findall(r"\bfunction\b", source))
    locals_count = len(re.findall(r"\blocal\b", source))
    requires = len(re.findall(r"\brequire\s*\(", source))

    signal_counts = {name: count_patterns(source, patterns) for name, patterns in SIGNALS.items()}
    risk = 0
    risk += min(35, signal_counts["dynamic_code"] * 10)
    risk += min(25, signal_counts["hooks"] * 8)
    risk += min(20, signal_counts["filesystem"] * 5)
    risk += min(20, signal_counts["http"] * 5)

    recommendations = []
    if signal_counts["remote_calls"]:
        recommendations.append("Open Remote Spy or Runtime Monitor and compare this script with remote call activity.")
    if requires:
        recommendations.append("Use Dependency Graph to inspect required ModuleScripts before editing behavior.")
    if signal_counts["dynamic_code"] or signal_counts["hooks"]:
        recommendations.append("Review dynamic execution and hook usage manually; automated summaries can miss intent.")
    if not recommendations:
        recommendations.append("Start with path/name search and inspect nearby scripts in Explorer.")

    output = {
        "ok": True,
        "worker": "python_deep_analysis",
        "language": "Python",
        "lines": lines,
        "bytes": len(source.encode("utf-8", "replace")),
        "functions": functions,
        "locals": locals_count,
        "requires": requires,
        "signals": signal_counts,
        "riskScore": risk,
        "topIdentifiers": top_identifiers(source),
        "recommendations": recommendations,
    }
    print(json.dumps(output, ensure_ascii=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
