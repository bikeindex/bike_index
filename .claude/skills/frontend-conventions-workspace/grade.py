"""Grade frontend-conventions eval outputs against per-eval assertions.

Reads each eval's notes.md (a markdown file containing all of the agent's
inline-delivered code blocks) and writes grading.json with assertion pass/fail.
"""
import json
import re
from pathlib import Path

ITERATION = Path(__file__).parent / "iteration-1"

# Tailwind utility "shape" regex — matches a token that looks like a
# Tailwind utility class. Used to detect bare (un-prefixed) Tailwind usage.
TW_UTILITY_SHAPES = [
    r"^(flex|grid|hidden|block|inline|inline-flex|inline-block|relative|absolute|fixed|sticky|sr-only|truncate|italic|underline)$",
    r"^(rounded|rounded-(sm|md|lg|xl|2xl|3xl|full|none))$",
    r"^(shadow|shadow-(sm|md|lg|xl|2xl|inner|none))$",
    r"^(border|border-(\d|t|r|b|l|x|y))$",
    r"^(bg|text|border|ring|divide|fill|stroke|placeholder|caret|accent|outline|decoration)-[a-z\-]+(-\d+)?$",
    r"^(text-(xs|sm|base|lg|xl|\dxl))$",
    r"^font-(thin|extralight|light|normal|medium|semibold|bold|extrabold|black)$",
    r"^(p|px|py|pt|pr|pb|pl)-\d+(\.\d+)?$",
    r"^(m|mx|my|mt|mr|mb|ml)-\d+(\.\d+)?$",
    r"^(-?(m|mx|my|mt|mr|mb|ml))-\d+(\.\d+)?$",  # negative margins
    r"^(w|h|min-w|max-w|min-h|max-h)-(\d+|full|auto|screen|fit|\d+/\d+|\[[^\]]+\])$",
    r"^(gap|space-x|space-y)-\d+(\.\d+)?$",
    r"^(top|right|bottom|left|inset|inset-x|inset-y)-\d+(\.\d+)?$",
    r"^(-(top|right|bottom|left))-\d+(\.\d+)?$",
    r"^z-\d+$",
    r"^opacity-\d+$",
    r"^items-(start|end|center|baseline|stretch)$",
    r"^justify-(start|end|center|between|around|evenly)$",
    r"^(flex-row|flex-col|flex-wrap|flex-grow|flex-shrink)$",
    r"^(uppercase|lowercase|capitalize|normal-case)$",
    r"^tracking-[a-z]+$",
    r"^leading-(\d+|none|tight|snug|normal|relaxed|loose)$",
]
TW_REGEX = re.compile("|".join(TW_UTILITY_SHAPES))

# Class attributes in HTML/ERB and Ruby hash form
CLASS_ATTR_PATTERNS = [
    re.compile(r'class\s*=\s*"([^"]*)"'),
    re.compile(r"class\s*=\s*'([^']*)'"),
    re.compile(r'class:\s*"([^"]*)"'),
    re.compile(r"class:\s*'([^']*)'"),
]

PROJECT_PREFIX_OK = ("tw:", "twinput", "twlabel", "twlink", "twbtn", "twselect", "twcheckbox")


def class_tokens_from(text):
    """Yield (token, full_class_value, line_no) for every class attribute in text."""
    for line_no, line in enumerate(text.splitlines(), start=1):
        for pat in CLASS_ATTR_PATTERNS:
            for m in pat.finditer(line):
                value = m.group(1)
                # Skip ERB interpolations
                if "<%=" in value or "#{" in value:
                    # Strip interpolations conservatively
                    value = re.sub(r"#\{[^}]+\}", "", value)
                    value = re.sub(r"<%=[^%]+%>", "", value)
                for token in value.split():
                    yield token, value, line_no


def find_bare_tailwind(text):
    """Return list of (line_no, token, class_value) for bare Tailwind utilities."""
    bare = []
    for token, value, line_no in class_tokens_from(text):
        # Strip pseudo-class prefixes that Tailwind allows: hover:, focus:, dark:, sm:, md:, lg:, xl:, 2xl:
        # When `tw:` is at the front of any of these, it's fine.
        if token.startswith(PROJECT_PREFIX_OK):
            continue
        # Strip variant prefixes (handles dark:bg-..., sm:flex, etc.)
        # If a token has variants but NOT tw:, it's still bare.
        # Drop variants to check the underlying utility shape.
        leaf = token.split(":")[-1]
        if TW_REGEX.match(leaf):
            bare.append((line_no, token, value))
    return bare


def grade_eval_0(text):
    results = []

    # A1: input has twinput
    has_twinput = bool(re.search(r"\btwinput\b", text))
    results.append({
        "text": "Form input element uses the `twinput` class",
        "passed": has_twinput,
        "evidence": "Found `twinput` reference" if has_twinput else "No `twinput` found in output",
    })

    # A2: label has twlabel
    has_twlabel = bool(re.search(r"\btwlabel\b", text))
    results.append({
        "text": "Form label uses the `twlabel` class",
        "passed": has_twlabel,
        "evidence": "Found `twlabel` reference" if has_twlabel else "No `twlabel` found in output",
    })

    # A3: tw: prefix on Tailwind utilities
    bare = find_bare_tailwind(text)
    has_tw = "tw:" in text
    if not has_tw:
        results.append({
            "text": "Tailwind utility classes use the `tw:` prefix",
            "passed": False,
            "evidence": "No `tw:` prefix found at all",
        })
    elif bare:
        sample = "; ".join(f"line {ln}: `{tok}`" for ln, tok, _ in bare[:3])
        results.append({
            "text": "Tailwind utility classes use the `tw:` prefix",
            "passed": False,
            "evidence": f"{len(bare)} bare Tailwind utility token(s). Examples: {sample}",
        })
    else:
        results.append({
            "text": "Tailwind utility classes use the `tw:` prefix",
            "passed": True,
            "evidence": "All Tailwind utility tokens are `tw:`-prefixed",
        })

    return results


def grade_eval_1(text):
    results = []

    # A1: count rendered with number_display
    count_through_nd = bool(re.search(r"number_display\([^)]*(count|bikes_count|@bikes_count)[^)]*\)", text))
    results.append({
        "text": "Bike count is rendered through `number_display`",
        "passed": count_through_nd,
        "evidence": "Found number_display(count-like)" if count_through_nd else "No number_display call wrapping a count-like value",
    })

    # A2: total value rendered with number_display
    value_through_nd = bool(
        re.search(r"number_display\([^)]*(value|total|sum|dollars|amount|cents)[^)]*\)", text)
    )
    results.append({
        "text": "Total bike value is rendered through `number_display`",
        "passed": value_through_nd,
        "evidence": "Found number_display(value-like)" if value_through_nd else "Value not passed through number_display (used MoneyFormatter or raw)",
    })

    # A3: tw: prefix
    bare = find_bare_tailwind(text)
    has_tw = "tw:" in text
    if not has_tw:
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": False, "evidence": "No `tw:` prefix found"})
    elif bare:
        sample = "; ".join(f"line {ln}: `{tok}`" for ln, tok, _ in bare[:3])
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": False, "evidence": f"{len(bare)} bare token(s). Examples: {sample}"})
    else:
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": True, "evidence": "All `tw:`-prefixed"})

    return results


def ruby_code_blocks(text):
    """Return list of code-block contents that look like Ruby (component .rb files)."""
    blocks = []
    for fence_lang, code in re.findall(r"```(\w*)\n(.*?)```", text, re.DOTALL):
        if fence_lang == "ruby" or "class " in code and "def " in code and "<%" not in code:
            blocks.append(code)
    return blocks


def grade_eval_2(text):
    results = []

    # A1: kwarg initialize
    kwarg_init = bool(re.search(r"def\s+initialize\([^)]*\bbike:[^)]*\)", text))
    results.append({
        "text": "Component `initialize` uses keyword arguments (e.g. `def initialize(bike:)`)",
        "passed": kwarg_init,
        "evidence": "Found `def initialize(bike:)`" if kwarg_init else "No keyword-arg initializer",
    })

    # A2: no attr_accessor / attr_reader IN the ruby code (not in prose narrative)
    ruby_blocks = ruby_code_blocks(text)
    has_attr = any(re.search(r"\battr_(accessor|reader|writer)\b", b) for b in ruby_blocks)
    results.append({
        "text": "Component does NOT use `attr_accessor`/`attr_reader`",
        "passed": not has_attr,
        "evidence": "No attr_* found" if not has_attr else "Found `attr_reader`/`attr_accessor` in component",
    })

    # A3: helpers. prefix (excluding *_path)
    # Find calls to known Rails helpers without `helpers.` prefix
    rails_helpers = [
        "time_ago_in_words", "link_to", "content_tag", "number_to_currency",
        "number_with_delimiter", "truncate", "pluralize", "simple_format",
        "image_tag", "button_to", "sanitize", "capture",
    ]
    bad_calls = []
    # Look in code-block content only (between triple backticks)
    for code in re.findall(r"```[a-z]*\n(.*?)```", text, re.DOTALL):
        # Only check ERB templates (heuristic: contains `<%`)
        if "<%" not in code:
            continue
        for h in rails_helpers:
            # Match helper call NOT preceded by `helpers.`
            for m in re.finditer(rf"(?<!helpers\.)(?<!\w){h}\s*\(", code):
                # Skip if the helper is being used inside a Ruby string
                bad_calls.append(h)
    if bad_calls:
        results.append({
            "text": "Component template uses `helpers.` prefix when calling Rails view helpers",
            "passed": False,
            "evidence": f"Bare helper calls in template: {', '.join(set(bad_calls))}",
        })
    else:
        results.append({
            "text": "Component template uses `helpers.` prefix when calling Rails view helpers",
            "passed": True,
            "evidence": "No bare Rails helper calls detected in templates",
        })

    # A3.5: no helpers.<path>_path (paths should not be prefixed)
    bad_path_prefix = re.findall(r"helpers\.\w+_path\b", text)
    if bad_path_prefix:
        # Add as a soft signal to the helpers. assertion above? Or separate? Keep as a separate observation.
        pass

    # A4: number_display for year and value
    nd_year = bool(re.search(r"number_display\([^)]*\byear\b[^)]*\)", text))
    nd_value = bool(re.search(r"number_display\([^)]*\bvalue\b[^)]*\)", text))
    results.append({
        "text": "Year and value are rendered through `number_display`",
        "passed": nd_year and nd_value,
        "evidence": f"year={nd_year}, value={nd_value}",
    })

    # A5: tw: prefix
    bare = find_bare_tailwind(text)
    has_tw = "tw:" in text
    if not has_tw:
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": False, "evidence": "No `tw:` prefix found"})
    elif bare:
        sample = "; ".join(f"line {ln}: `{tok}`" for ln, tok, _ in bare[:3])
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": False, "evidence": f"{len(bare)} bare token(s). Examples: {sample}"})
    else:
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": True, "evidence": "All `tw:`-prefixed"})

    return results


def grade_eval_3(text):
    results = []

    # A1: Uses Stimulus (either authored a new controller, OR reused an existing one).
    # Coffee check: only fail if a `.coffee` file path appears in a code-block heading
    # (e.g., `### app/.../foo.coffee`) — narrative mentions like "no CoffeeScript" don't count.
    coffee_files = re.findall(r"^#{1,6}\s+.*\.coffee\b", text, re.MULTILINE) + re.findall(r"`[^`\n]+\.coffee`", text)
    has_coffee_file = bool(coffee_files)

    has_stimulus_import = bool(
        re.search(r"from\s+['\"]@hotwired/stimulus['\"]", text)
        or re.search(r"from\s+['\"]stimulus['\"]", text)
    )
    has_extends_controller = "extends Controller" in text
    authored_stimulus = has_stimulus_import and has_extends_controller

    # Reused existing Stimulus controller — recognized by `data-controller="..."` attribute
    # plus a mention of reusing or the project's `ui--dropdown`.
    reused_stimulus = bool(
        re.search(r'data-controller\s*=\s*"[^"]*"', text)
        and (
            "ui--dropdown" in text
            or re.search(r"reuse[ds]?\s+(the\s+)?(existing\s+)?[`\w]*\s*[Ss]timulus", text)
            or re.search(r"reuse[ds]?\s+.*ui--dropdown", text)
        )
    )

    passed = (authored_stimulus or reused_stimulus) and not has_coffee_file
    evidence_bits = []
    if authored_stimulus:
        evidence_bits.append("Authored Stimulus controller (import + extends Controller)")
    elif reused_stimulus:
        evidence_bits.append("Reused existing Stimulus controller (data-controller attr + reuse mention)")
    else:
        evidence_bits.append("No Stimulus controller authored or referenced")
    evidence_bits.append(f"CoffeeScript file: {'yes' if has_coffee_file else 'no'}")
    results.append({
        "text": "Uses Stimulus.js (authored OR reused existing controller; no `.coffee` files)",
        "passed": passed,
        "evidence": "; ".join(evidence_bits),
    })

    # A2: number_display for unread count
    nd_unread = bool(
        re.search(r"number_display\([^)]*(unread|count|notification)[^)]*\)", text)
    )
    results.append({
        "text": "Unread count is rendered through `number_display`",
        "passed": nd_unread,
        "evidence": "Found number_display(unread-like)" if nd_unread else "No number_display wrapping unread count",
    })

    # A3: tw: prefix
    bare = find_bare_tailwind(text)
    has_tw = "tw:" in text
    if not has_tw:
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": False, "evidence": "No `tw:` prefix found"})
    elif bare:
        sample = "; ".join(f"line {ln}: `{tok}`" for ln, tok, _ in bare[:3])
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": False, "evidence": f"{len(bare)} bare token(s). Examples: {sample}"})
    else:
        results.append({"text": "Tailwind utility classes use the `tw:` prefix", "passed": True, "evidence": "All `tw:`-prefixed"})

    # A4: ViewComponent kwarg + helpers. prefix (if a component is created)
    component_created = bool(re.search(r"class\s+\w*Component\b", text))
    if not component_created:
        results.append({
            "text": "If structured as a ViewComponent, initialize uses keyword args and template uses `helpers.` prefix",
            "passed": True,
            "evidence": "No ViewComponent created — vacuously satisfied",
        })
    else:
        kwarg_ok = bool(re.search(r"def\s+initialize\([^)]*\w+:[^)]*\)", text))
        # Check helpers. prefix usage in templates (look for any `helpers.` occurrence)
        helpers_used_correctly = "helpers." in text
        # Also check for `attr_*` IN ruby code (skill says prefer instance variables)
        ruby_blocks = ruby_code_blocks(text)
        attr_violation = any(re.search(r"\battr_(accessor|reader|writer)\b", b) for b in ruby_blocks)
        bits = []
        bits.append(f"kwarg init: {kwarg_ok}")
        bits.append(f"helpers. used: {helpers_used_correctly}")
        bits.append(f"attr_*: {'present (violates skill)' if attr_violation else 'absent'}")
        passed = kwarg_ok and helpers_used_correctly and not attr_violation
        results.append({
            "text": "If structured as a ViewComponent, initialize uses keyword args and template uses `helpers.` prefix (no attr_*)",
            "passed": passed,
            "evidence": "; ".join(bits),
        })

    return results


GRADERS = {
    0: grade_eval_0,
    1: grade_eval_1,
    2: grade_eval_2,
    3: grade_eval_3,
}


def main():
    eval_dirs = sorted(p for p in ITERATION.iterdir() if p.is_dir() and p.name.startswith("eval-"))
    for eval_dir in eval_dirs:
        meta = json.loads((eval_dir / "eval_metadata.json").read_text())
        eval_id = meta["eval_id"]
        for variant in ("with_skill", "without_skill"):
            run_dir = eval_dir / variant
            notes_path = run_dir / "outputs" / "notes.md"
            if not notes_path.exists():
                print(f"SKIP {eval_dir.name}/{variant}: no notes.md")
                continue
            text = notes_path.read_text()
            assertions = GRADERS[eval_id](text)
            grading = {
                "eval_id": eval_id,
                "eval_name": meta["eval_name"],
                "variant": variant,
                "expectations": assertions,
                "passed_count": sum(1 for a in assertions if a["passed"]),
                "total_count": len(assertions),
            }
            (run_dir / "grading.json").write_text(json.dumps(grading, indent=2))
            print(f"{eval_dir.name}/{variant}: {grading['passed_count']}/{grading['total_count']}")


if __name__ == "__main__":
    main()
