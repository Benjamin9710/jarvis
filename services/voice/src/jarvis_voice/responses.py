from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


CommandAction = Literal["turn_on", "turn_off"]


@dataclass(frozen=True, slots=True)
class JarvisResponseText:
    summary_text: str
    spoken_text: str


class JarvisResponseComposer:
    def compose_success(self, action: CommandAction, target: str) -> JarvisResponseText:
        title_target = self._title_target(target)
        article_target = self._article_target(target)

        if action == "turn_on":
            return JarvisResponseText(
                summary_text=f"{title_target} lights turned on",
                spoken_text=f"Certainly. {article_target} lights are now on.",
            )

        return JarvisResponseText(
            summary_text=f"{title_target} lights turned off",
            spoken_text=f"Certainly. {article_target} lights are now off.",
        )

    def compose_unsupported(self) -> JarvisResponseText:
        return JarvisResponseText(
            summary_text="Command not available",
            spoken_text="I'm afraid I can't do that just yet.",
        )

    def _title_target(self, target: str) -> str:
        words = [word for word in target.strip().split(" ") if word]
        if not words:
            return "Unknown"
        return " ".join(word.capitalize() for word in words)

    def _article_target(self, target: str) -> str:
        normalized = " ".join(target.strip().split())
        if not normalized:
            return "The"
        if normalized.lower().startswith("the "):
            return normalized[:1].upper() + normalized[1:]
        return f"The {normalized}"
