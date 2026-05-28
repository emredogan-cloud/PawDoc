"""Video-path tests (Phase 3.2): frame plumbing, pinned video model routing,
and the prompt noting keyframes. No API keys needed (fake provider)."""
from app import config
from app.cache import InMemoryCache
from app.models import AnalyzeRequest, PetContext, TriageLevel
from app.pipeline import AnalysisPipeline
from app.prompts import build_user_prompt
from app.providers import GeminiProvider


class FakeProvider:
    def __init__(self, name, tier, response):
        self.name = name
        self.tier = tier
        self.response = response
        self.calls = 0
        self.last_frame_urls = None

    def analyze(self, system_prompt, user_prompt, image_url=None, frame_urls=None,
                pet_context_block=None):
        self.calls += 1
        self.last_frame_urls = frame_urls
        self.last_pet_context = pet_context_block
        return dict(self.response)


def _res(level, conf):
    return {
        "triage_level": level, "confidence": conf, "primary_concern": "x",
        "visible_symptoms": [], "differential": [], "recommended_actions": ["a"],
        "urgency_timeframe": "routine", "disclaimer_required": True,
    }


def test_analyze_request_accepts_frames_and_defaults_empty():
    assert AnalyzeRequest(input_type="text", pet=PetContext(species="dog")).frame_urls == []
    req = AnalyzeRequest(
        input_type="video",
        frame_urls=["https://r2/f1.jpg", "https://r2/f2.jpg"],
        pet=PetContext(species="dog"),
    )
    assert len(req.frame_urls) == 2


def test_gemini_selects_pinned_video_model_for_frames():
    p = GeminiProvider(api_key="k")
    assert p.select_model(["f1", "f2"]) == config.VIDEO_MODEL == "gemini-2.0-flash"
    assert p.select_model(None) == config.TIER2_MODEL


def test_prompt_notes_video_keyframes():
    req = AnalyzeRequest(
        input_type="video",
        frame_urls=["a", "b", "c", "d"],
        pet=PetContext(species="cat"),
    )
    prompt = build_user_prompt(req)
    assert "4 video keyframes" in prompt


def test_pipeline_passes_frames_to_provider_for_video():
    t2 = FakeProvider("gemini", 2, _res("NORMAL", 0.95))
    t3 = FakeProvider("claude", 3, _res("NORMAL", 0.9))
    pipeline = AnalysisPipeline(tier2=t2, tier3=t3, cache=InMemoryCache())
    req = AnalyzeRequest(
        input_type="video",
        frame_urls=["https://r2/f1.jpg", "https://r2/f2.jpg"],
        pet=PetContext(species="dog", age_years=2.0),
    )
    out = pipeline.run(req)
    assert out.tier_used == 2  # video starts at Tier 2 (Gemini)
    assert t2.last_frame_urls == ["https://r2/f1.jpg", "https://r2/f2.jpg"]
    assert out.result.triage_level is TriageLevel.NORMAL
