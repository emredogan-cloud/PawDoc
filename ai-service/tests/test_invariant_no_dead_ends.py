"""THE COMPANY INVARIANT (evolution J13): no output path terminates without an
action and a timeframe, and nothing ever lands below the ladder floor.

Every fallback the pipeline can produce — kill-switch, both-tiers-down,
media-unreadable, moderation-reject, insufficient-information, floor-tighten,
override — must return a member of the closed ladder, a non-empty
urgency_timeframe, and (on the floor) an explicit recheck_hours. A regression
here is not a bug; it is the product's core promise breaking.
"""
from unittest.mock import patch

from app import config
from app.cache import InMemoryCache
from app.models import ActionLevel, AnalyzeRequest, PetContext
from app.pipeline import AnalysisPipeline
from app.providers import ProviderError


class _Stub:
    def __init__(self, name, tier, response=None, fail=False):
        self.name, self.tier, self.response, self.fail = name, tier, response, fail

    def analyze(self, *_a, **_k):
        if self.fail:
            raise ProviderError(f"{self.name} down")
        return dict(self.response)


class _Reject:
    def is_safe_bytes(self, data, mime_type):
        return False


def _res(action, conf, recheck=24):
    return {
        "action": action, "confidence": conf, "observation": "x",
        "visible_symptoms": [], "vets_look_for": [], "watch_for": [],
        "recommended_actions": ["step"], "urgency_timeframe": "today",
        "recheck_hours": recheck, "disclaimer_required": True,
    }


def _req(text="mild itching for a day", input_type="text", image=None):
    return AnalyzeRequest(
        input_type=input_type, text_description=text, image_url=image,
        pet=PetContext(species="dog", age_years=3.0),
    )


def _assert_invariant(outcome):
    r = outcome.result
    assert r.action in ActionLevel, "action must be on the closed ladder"
    assert r.urgency_timeframe.strip(), "every output carries a timeframe"
    assert r.recommended_actions or r.action is ActionLevel.GET_HELP_NOW, \
        "every non-red output carries at least one action step"
    if r.action is ActionLevel.WATCH_AND_RECHECK:
        assert r.recheck_hours is not None, "the floor always schedules a re-check"
    assert r.disclaimer_required is True


def _pipe(t2=None, t3=None, moderator=None, cache=None):
    return AnalysisPipeline(
        tier2=t2 or _Stub("gemini", 2, _res("WATCH_AND_RECHECK", 0.9)),
        tier3=t3 or _Stub("claude", 3, _res("WATCH_AND_RECHECK", 0.9)),
        cache=cache or InMemoryCache(),
        moderator=moderator,
        cross_verify_executor=lambda job: None,
    )


def test_invariant_kill_switch():
    cache = InMemoryCache()
    cache.set(config.KILL_SWITCH_CACHE_KEY, "1")
    _assert_invariant(_pipe(cache=cache).run(_req()))


def test_invariant_both_tiers_down():
    _assert_invariant(
        _pipe(t2=_Stub("g", 2, None, fail=True), t3=_Stub("c", 3, None, fail=True)).run(_req())
    )


def test_invariant_media_unreadable():
    from app.media import MediaFetchError

    def _boom(url):
        raise MediaFetchError("boom")

    with patch("app.pipeline.gather_media", _boom):
        _assert_invariant(_pipe().run(_req(input_type="photo", image="https://r2/x.jpg")))


def test_invariant_moderation_reject():
    with patch("app.pipeline.gather_media", lambda url: [(b"x", "image/png")]):
        _assert_invariant(
            _pipe(moderator=_Reject()).run(_req(input_type="photo", image="https://r2/x.jpg"))
        )


def test_invariant_insufficient_information():
    low = _res("WATCH_AND_RECHECK", 0.2)
    _assert_invariant(_pipe(t2=_Stub("g", 2, low), t3=_Stub("c", 3, low)).run(_req()))


def test_invariant_override():
    _assert_invariant(_pipe().run(_req(text="my dog is not breathing")))


def test_invariant_floor_without_model_recheck_hours_is_backstopped():
    no_recheck = _res("WATCH_AND_RECHECK", 0.95, recheck=None)
    out = _pipe(t2=_Stub("g", 2, no_recheck), t3=_Stub("c", 3, no_recheck)).run(_req())
    _assert_invariant(out)
    assert out.result.recheck_hours == 24  # server backstop


def test_invariant_every_ladder_value_passes_through():
    for action in ("GET_HELP_NOW", "CALL_TODAY", "BOOK_VISIT", "WATCH_AND_RECHECK"):
        ok = _res(action, 0.95)
        out = _pipe(t2=_Stub("g", 2, ok), t3=_Stub("c", 3, ok)).run(_req())
        _assert_invariant(out)
        assert out.result.action.value == action
