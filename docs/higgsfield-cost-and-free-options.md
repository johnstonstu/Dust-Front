# Desert Front — Higgsfield cost & free options

Read-only cost audit (2026-09-16). No generation jobs submitted for this audit. Credit quotes use catalog tools plus `get_cost:true` preflights (zero spend; balance unchanged at 6.35).

---

## 1. Balance, plan, trial / unlim caveats

| Item | Value |
|------|--------|
| **Credits** | **6.35** |
| **Plan** | **free** |
| **Free-trial unlim (MCP)** | **Not spendable** (`unlim.available: false`) |
| **Balance after this audit** | Still **6.35** (preflights only) |

### Trial / unlimited caveats (important)

- **MCP “Free Generations” / unlimited models are not usable here.** Higgsfield states unlimited models and Free Generations are on **higgsfield.ai only**, not via MCP/CLI/Canvas/Supercomputer. Passing `use_unlim` while unavailable returns a typed rejection (no charge).
- **Eligible for a 3-day Free Plus Trial** ($0 today): **100 MCP-only credits** for 3 days. Requires a card; **auto-renews at $49/mo** unless cancelled (“cancel auto-renewal”). Trial credits **do not appear on higgsfield.ai**. Unlimited / Free Generations are **not** part of the trial.
- Paid options shown: Plus annual ~**1,000 credits/mo for $39**; Ultra annual ~**3,000 credits/mo for $99**; one-time top-up packs of **500 / 1,000 / 2,000 / 4,000** credits. Prices exclude VAT/local taxes.

**Stuart takeaway:** Treat the account as a small free-credit wallet. Do not assume unlim or web Free Generations work from Cursor/MCP.

---

## 2. Approximate credit costs (cheap → mid)

All figures from live `get_cost:true` preflights unless noted. Prefer the **exact** number when display vs exact differ.

### Still images (text-to-image, 16:9, count 1)

| Model | Role | Exact credits | Notes |
|-------|------|---------------|--------|
| **`z_image`** | Budget / fast stylized | **0.15** | Cheapest reliable still; smoke-tested |
| `soul_location` | Environments / landscapes | **0.12** (UI may show 1) | Good thematic fit; confirm exact before spend |
| `soul_cinematic` | Cinema-grade stills | **0.12** (UI may show 1) | Same display quirk |
| `gpt_image_2` | Mid, quality=`low`, 1k | **0.5** | quality=`medium` → **1** |
| `nano_banana` | Budget realistic | **1** | Supports unlim on web; not usable here |
| `nano_banana_2_lite` | Lite next-gen | **1** | |
| `gpt_image_2_5` | Default general (flare, low, 1k) | **1** | |
| `flux_2` | pro, 1k | **1** | |
| `recraft_v4_1` | standard, 1k | **1.25** | Strong for vector/logo; overkill for mood stills |
| `nano_banana_pro` | 1k | **2** | |
| `cinematic_studio_2_5` | 1k | **2** | |

**Practical still budget for Desert Front mood:** prefer **`z_image` (~0.15)**; step up to soul/cinematic (~0.12–1) or GPT/Nano (~0.5–1) only if quality needs it.

### Short video (text-to-video / budget clips)

| Model | Config | Exact credits | Notes |
|-------|--------|---------------|--------|
| **`seedance1_5`** (Seedance 1.5 Pro) | 4s, 480p, silent | **2.4** | **Cheapest short video found** |
| `veo3_1_lite` | 4s, silent (default audio off) | **4** | Tagged budget/affordable |
| `seedance_2_0_mini` | 5s, 480p, silent | **5** | 5s 720p + audio → **12.5** |
| `kling3_0_turbo` | 5s, 720p | **7.5** | |
| `minimax_h3_max` | 5s, 480p | **7.5** | |
| `cinematic_studio_video` | 5s | **8** | |
| `happy_horse_video` | 5s, 720p | **12.5** | |
| `wan2_6` | 5s, 720p | **13** | |
| `seedance_2_5` | t2v 5s, 480p, silent | **15** | Mid/premium default-ish |

**Catalog note:** `flux_3_video_edit` documents **1 credit per second** of processed clip (edit path, not fresh mood generation).

**Marketing Studio v2:** pricing is exposed via `marketing_studio_v2_costs` (cost units → credits; video = fixed + per-second). Widget-oriented; not needed for Desert Front mood stills. Image-to-video **presets** (`presets_show`) are creative templates, not a free tier.

**Wallet math:** with **6.35** credits you can afford ~**42×** `z_image` stills, or **~2×** cheapest short videos (`seedance1_5` @ 2.4), but **not** a mid video like Seedance 2.5 @ 15.

---

## 3. What we already spent

Source: `internal/higgsfield-smoke-test.md` + live `transactions`.

| Spend | Credits | When | Notes |
|-------|---------|------|--------|
| **Desert Front smoke (`z_image`)** | **−0.15** | 2026-09-16 | Mood still saved to Context media |
| Prior Seed Audio 1.0 (×5, unrelated) | −0.6 / −0.8 / −0.8 / −0.6 / −0.7 | 2026-09-15 | Not Desert Front art |

**Desert Front art spend to date: 0.15 credits.**  
Artifact: `/cursor/stores/bc-ee68ceb4-8a72-44a3-9449-02c81fe379e2/media/desert-front-mood-still.png` (2048×1152 PNG).

Preflight before that job also quoted **0.15**; balance moved 6.5 → 6.35.

---

## 4. Free / near-free alternatives (this Cursor / cloud setup)

Honest quality limits for **Desert Front mood art**:

| Option | Cost | Fit for desert mood | Limits |
|--------|------|---------------------|--------|
| **Reuse existing smoke still** | Free | High for placeholders / first-viewport reference | One look; no new variants without spend |
| **SVG / CSS / HTML atmosphere** | Free | Good for UI chrome, gradients, silhouettes, heat-haze motion | Not photoreal; design craft required |
| **ffmpeg** (installed) | Free | Crop/retime/grade existing stills or stock clips | Needs source media; not generative |
| **Cursor `GenerateImage`** | No Higgsfield credits | Quick concept / UI mock assets when Stuart **explicitly** asks | Separate Cursor tool; not Higgsfield quality control; not for silent “just generate” |
| **Public domain / stock** (Wikimedia, Unsplash, etc.) | Free (license-aware) | Real desert photography for mood boards | Licensing + brand fit; not “Desert Front” original IP |
| **Local FOSS SD / Comfy / ImageMagick / Pillow** | — | — | **Not installed** on this VM (no Pillow, no ImageMagick CLI, no SD stack). Pure Python + numpy can write crude rasters only |
| **Higgsfield web Free Generations / unlim** | $0 on web (plan-gated) | N/A from MCP | **Not accessible from this MCP path** |
| **3-day Plus trial (100 MCP credits)** | $0 then **$49/mo** if not cancelled | Extra headroom | Card required; not a durable free path |

**Other MCPs in this session** (GitHub, X, cursor-cloud, subscriptions): no free image-generation substitute for mood art.

---

## 5. Recommended default workflow (Stuart)

1. **Prefer free first:** reuse `media/desert-front-mood-still.png`, SVG/CSS, stock/PD, or Cursor `GenerateImage` only if Stuart explicitly requests an image.
2. **Before any Higgsfield generation:** run / quote **`get_cost:true`**, state model + exact credits + remaining balance, and **wait for explicit OK**.
3. **Default paid still:** `z_image` @ **~0.15** unless Stuart asks for higher fidelity.
4. **Default paid short video (if ever needed):** `seedance1_5` @ **~2.4** (4s / 480p) — still expensive relative to the 6.35 wallet; confirm first.
5. **Do not** opt into trial/unlim/spend to “save” credits without Stuart’s OK. **Do not** assume MCP unlim works.
6. After any approved spend: confirm new balance and log the job in Project Context.

---

## Method notes

- Tools used: `balance`, `show_plans_and_credits`, `transactions`, `models_explore`, `presets_show`, `marketing_studio_v2_costs`, and `generate_*` **only** with `get_cost:true` (no jobs).
- Prices can change; re-preflight before each spend.
