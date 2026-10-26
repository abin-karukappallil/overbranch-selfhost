"""
backend/tex_tool_output.py — the TeX tool's own chatter, kept out of the TeX log
===============================================================================
A TeX distribution's command line tools write two kinds of thing to their
output: what happened to the *document* (what every error parser here wants)
and what the tool thinks of its *own installation* (what none of them want).

MiKTeX — the distribution every Windows install of OverBranch uses — writes
the second kind to stderr on **every** run of **every** one of its programs,
whatever the document says and whether or not the run succeeded::

    pdflatex: security risk: running with elevated privileges
    pdflatex: major issue: So far, you have not checked for MiKTeX updates.
    kpsewhich: major issue: So far, you have not checked for MiKTeX updates.
    synctex: security risk: running with elevated privileges

Those four lines come from a compile that exited 0 and wrote a PDF.
``compiler.py`` reads stdout and stderr as one log, so they land in it, and the
error parsers treat the tail of a log as the error when nothing more specific
matched (``latex_error_fixer.parse_compilation_errors``). The last line of a
clean MiKTeX log is the update nag, so a document with nothing wrong with it
was reported as failing with::

    Failing errors: pdflatex: major issue: So far, you have not checked for
    MiKTeX updates.

The agent's compile gate then rolled the edit back, and the repair model was
handed a nag message in place of a TeX error, so no repair could ever succeed.

Dropping these lines wherever tool output is read fixes it for every Windows
install at once, without depending on the machine's MiKTeX configuration,
privileges or network access (the nag cannot be silenced without a successful
update check, and a self-hosted server often runs elevated, which is what the
``security risk`` line reports).

Only the distribution's own advisory shape is removed. TeX's output never uses
it — TeX errors are ``! ...`` or ``./main.tex:12: ...`` — and MiKTeX's real
aborts (``pdflatex: fatal: ...``, ``pdflatex: Data: ...``) are left in place,
because those do explain a failed run.
"""

from __future__ import annotations

import re

# `<program>: <severity> issue: <message>` and `<program>: security risk: <message>`,
# the two shapes MiKTeX's application framework prints its findings in. The program
# prefix is optional: `miktex.exe` itself omits it. The severities are MiKTeX's own
# (critical/major/minor/trivial) and all of them describe the installation, never the
# document — "you have not checked for updates" is filed as `major`.
_RE_TOOL_DIAGNOSTIC = re.compile(
    r"^(?:[\w.+-]+: )?(?:(?:critical|major|minor|trivial) issue|security risk): ",
    re.IGNORECASE,
)


def is_tool_diagnostic(line: str) -> bool:
    """True when ``line`` is the TeX distribution talking about itself, not the document."""
    return bool(_RE_TOOL_DIAGNOSTIC.match((line or "").strip()))


def strip_tool_diagnostics(text: str) -> str:
    """
    ``text`` without the distribution's self-advisory lines.

    Returns the original string unchanged when there is nothing to drop, so a log
    from a distribution that does not emit them (TeX Live writes nothing to stderr)
    keeps its exact bytes, including its trailing newline.
    """
    if not text:
        return text
    lines = text.splitlines()
    kept = [ln for ln in lines if not is_tool_diagnostic(ln)]
    if len(kept) == len(lines):
        return text
    return "\n".join(kept)
