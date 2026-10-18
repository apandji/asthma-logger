# Apple Intelligence and Siri: for later (not MVP)

Oct 17, 2026. The on-device model no longer writes the Insights sentence, and the clinical → poetic voice slider is
gone: felt air speaks in one plain voice, from the template narrator. Foundation Models stays for one quiet job,
suggesting tags from a voice note (you confirm them). These are ideas to discuss after the MVP, not decisions.

| Idea | What it would do | Why it fits | Watch out for |
|---|---|---|---|
| **App Intents + Siri phrases** | "Log my rescue inhaler", "Add a note to felt air", "How's the air for me today?" | Hands-free logging mid-flare is the core job. The Lock Screen mic already runs on App Intents | The answer must stay a verdict ("looks like your baseline days"), never a risk or a count |
| **Shortcuts and the Action button** | One press logs a rescue and starts a voice note | Already half there (the Control Center control) | Overlaps with the felt button and the watch |
| **App Entities in Spotlight** | Moments and notes findable by place or words ("the park, April") | The diary becomes searchable | Privacy: what Spotlight indexes |
| **Summaries for a doctor visit** | Foundation Models turns a month of voice notes into a short, plain list for a provider | Fits the provider-review direction (docs/provider-review.md) | It summarises words people said, never the numbers; output checked like the narrator's was |
| **Visual Intelligence / photos** | Point the camera at a pet, a candle, a fire pit to tag a moment | The roadmap's photos step | Opt-in, on device only |
| **Siri suggestions** | Offer "Add a note" right after a press, or the look-ahead in the morning | Matches the Lock Screen prompt and morning look-ahead | Never alarming, never "you will" |

Rules that hold for any of these: code finds the pattern and the model only says it; no numbers on screen; nothing
leaves the device; facts, never causes.
