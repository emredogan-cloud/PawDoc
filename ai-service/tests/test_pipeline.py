"""Pipeline orchestration tests with fake providers (no API keys needed)."""
from app import config
from app.cache import InMemoryCache
from app.models import AnalyzeRequest, PetContext, TriageLevel
from app.pipeline import AnalysisPipeline
from app.providers import ProviderError


class FakeProvider:
    def __init__(self, name, tier, response=None, *, fail=False):
        self.name = name
        self.tier = tier
        self.response = response
        self.fail = fail
        self.calls = 0

    def analyze(self, system_prompt, user_prompt, image_url=None):
        self.calls += 1
        if self.fail:
            raise ProviderError(f"{self.name} forced failure")
        return dict(self.response)


def res(level, conf, **kw):
    base = {
        "triage_level": level,
        "confidence": conf,
        "primary_concern": "assessment",
        "visible_symptoms": [],
        "differential": [],
        "recommended_actions": ["follow up if needed"],
        "urgency_timeframe": "routine",
        "disclaimer_required": True,
    }
    base.update(kw)
    return base


def req(text=None, species="dog", age=3.0, low_quality=False):
    return AnalyzeRequest(
        input_type="text",
        text_description=text,
        pet=PetContext(species=species, age_years=age),
        low_input_quality=low_quality,
    )


def build(tier2=None, tier3=None, cache=None):
    return AnalysisPipeline(
        tier2=tier2 or FakeProvider("gemini", 2, res("NORMAL", 0.9)),
        tier3=tier3 or FakeProvider("claude", 3, res("MONITOR", 0.8)),
        cache=cache or InMemoryCache(),
    )


def test_temperature_is_locked_at_point_one():
    assert config.ANALYSIS_TEMPERATURE == 0.1


def test_emergency_override_runs_before_any_ai_call():
    t2 = FakeProvider("gemini", 2, res("NORMAL", 0.99))
    t3 = FakeProvider("claude", 3, res("NORMAL", 0.99))
    out = build(t2, t3).run(req("my dog had a seizure this morning"))
    assert out.result.triage_level is TriageLevel.EMERGENCY
    assert out.emergency_override_applied is True
    assert t2.calls == 0 and t3.calls == 0  # no AI was called


def test_tier2_high_confidence_is_accepted_without_tier3():
    t2 = FakeProvider("gemini", 2, res("NORMAL", 0.92))
    t3 = FakeProvider("claude", 3, res("MONITOR", 0.8))
    out = build(t2, t3).run(req())  # benign, no risk signals
    assert out.tier_used == 2
    assert out.result.triage_level is TriageLevel.NORMAL
    assert t3.calls == 0


def test_low_tier2_confidence_escalates_to_tier3():
    t2 = FakeProvider("gemini", 2, res("NORMAL", 0.5))
    t3 = FakeProvider("claude", 3, res("MONITOR", 0.82))
    out = build(t2, t3).run(req())
    assert out.tier_used == 3
    assert t3.calls >= 1
    assert out.result.triage_level is TriageLevel.MONITOR


def test_emergency_classification_is_cross_verified():
    t2 = FakeProvider("gemini", 2, res("NORMAL", 0.4))
    t3 = FakeProvider("claude", 3, res("EMERGENCY", 0.9))
    out = build(t2, t3).run(req("very lethargic"))  # no hardcoded keyword
    assert out.result.triage_level is TriageLevel.EMERGENCY
    assert out.cross_verified is True
    assert t3.calls == 2  # primary + cross-verify


def test_low_confidence_returns_insufficient_information():
    t2 = FakeProvider("gemini", 2, res("MONITOR", 0.5))
    t3 = FakeProvider("claude", 3, res("MONITOR", 0.4))  # below 0.60 floor
    out = build(t2, t3).run(req())
    assert out.result.triage_level is TriageLevel.MONITOR
    assert "Not enough information" in out.result.primary_concern


def test_cr4_borderline_normal_with_risk_signals_biases_to_monitor():
    # Tier 2 confidently says NORMAL, but the owner reports vomiting (a risk signal).
    t2 = FakeProvider("gemini", 2, res("NORMAL", 0.95))
    t3 = FakeProvider("claude", 3, res("NORMAL", 0.95))
    out = build(t2, t3).run(req("my cat is vomiting and lethargic"))
    assert out.result.triage_level is TriageLevel.MONITOR  # downgraded for safety
    assert out.tier_used == 3  # escalated during the re-check
    assert any("Monitor closely" in a for a in out.result.recommended_actions)


def test_cr19_kill_switch_returns_degraded():
    cache = InMemoryCache()
    cache.set(config.KILL_SWITCH_CACHE_KEY, "1")
    t2 = FakeProvider("gemini", 2, res("NORMAL", 0.99))
    out = build(t2, cache=cache).run(req())
    assert out.degraded is True
    assert out.result.triage_level is TriageLevel.MONITOR
    assert t2.calls == 0


def test_cr5_provider_failure_degrades_gracefully():
    t2 = FakeProvider("gemini", 2, fail=True)
    t3 = FakeProvider("claude", 3, fail=True)
    out = build(t2, t3).run(req())
    assert out.degraded is True
    assert out.result.triage_level is TriageLevel.MONITOR
    assert t2.calls == 2  # one retry before degrading


def test_disclaimer_is_always_required():
    out = build().run(req())
    assert out.result.disclaimer_required is True
