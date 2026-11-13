#!/usr/bin/env python3
"""Advisory AI review of Checkov findings + Terraform plan. Never fails the
build."""
import json
import os
import sys
import urllib.request
MODEL = os.environ.get("AI_MODEL", "gemini-flash-latest")
LIMIT = 20000




def checkov_findings(path):
    try:
         with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:
        return [], f"could not read Checkov report ({exc})"
    reports = data if isinstance(data, list) else [data]
    failed = []
    for rep in reports:
        failed += rep.get("results", {}).get("failed_checks", [])
    lines = [f"- {c['check_id']} {c['check_name']} | {c['resource']} |{c['file_path']}" 
             for c in failed]
    return lines, None




def read_text(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()[:LIMIT]
    except Exception as exc:
        return f"(could not read {path}: {exc})"




def ask_llm(prompt):
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key or key == "skip":
        return "_AI review skipped: no API key configured._"
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    body = json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode()
    headers = {"Content-Type": "application/json", "x-goog-api-key": key}
    req = urllib.request.Request(url, data=body, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
             return json.load(resp)["candidates"][0]["content"]["parts"][0]["text"]
    except Exception as exc:
        return f"_AI review unavailable: {exc}_"

def main():
    checkov_path, plan_path, out_path = sys.argv[1:4]
    lines, err = checkov_findings(checkov_path)
    findings = chr(10).join(lines)[:LIMIT] or "none"
    plan = read_text(plan_path)
    prompt = f'''You are a senior cloud security engineer reviewing a
Terraform change before it is deployed to AWS.
Self-Defending AWS Stack: Defense in Depth with Terraform, Jenkins, Prometheus, Grafana and AI
Reply in Markdown with exactly three sections: "## Change summary" (plain
English: what is created, changed, destroyed), "## Top risks" (max 5, ranked,
each naming the resource and a concrete Terraform fix), "## Verdict" (APPLY
or HOLD, with one sentence why).
Be concise. This review is advisory and a human approves the change.

Checkov failed checks:
{findings}

Terraform plan:
{plan}
'''
    answer = ask_llm(prompt)
    note = f" ({err})" if err else ""
    header = f"# AI security review ({MODEL})" + chr(10) + chr(10) + f"Checkov failed checks: {len(lines)}{note}" + chr(10) + chr(10)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(header + answer + chr(10))
    print(f"Wrote {out_path}")

main()